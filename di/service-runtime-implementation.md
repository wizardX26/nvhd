# Service runtime — bindings, cấu hình, eager/lazy và DI mẫu

Cập nhật: 2026-09-08. Tài liệu triển khai bổ sung cho [DI overview](di-overview.md) và [window/navigation](window-navigation-overview.md). Đây là thiết kế cho codebase đích, không phải source chạy được hoặc bản port API Telegram một-một. Giữ `UserContext/UserContextImpl`, bỏ `SharedContext/SharedContextImpl`; mọi dependency đến constructor/factory một cách tường minh.

## 1. ApplicationBindings: ranh giới platform

Fork ý tưởng [TelegramApplicationBindings](../../../submodules/AccountContext/Sources/AccountContext.swift), không fork nguyên danh sách closure có window toàn cục.

| Nhóm capability | ApplicationBindings cấp app | SceneBindings cấp scene |
| --- | --- | --- |
| Host/environment | Main app/extension/test, bundle/version, paths, capability được hỗ trợ | sceneID, scene activity và traits |
| System services | APNs token/events, background task acquisition/expiration, audio interruption, network/path, power/motion signals | Không đăng ký lại observer cấp app |
| External actions | Capability kiểm tra URL, settings; system API không cần presenter cụ thể | Mở URL/yêu cầu UI gắn scene, presenter, anchor, focus/orientation |
| UI | Không getTopWindow/global key window/presentNativeController | ScenePresenter, cùng UIWindowScene; weak callbacks hoặc registration tokens |

`ApplicationBindings` được dựng P0 ở composition root. Implementation UIKit/host bridge tiếp xúc API hệ điều hành; domain services nhận capability hẹp như `BackgroundTaskAccess`, `MotionSettings`, `AudioSessionAccess`, không nhận cả bindings nếu chỉ cần một nhóm. SceneDelegate feed lifecycle vào ApplicationActivity bằng sceneID; giữ phân biệt foreground và active. WakeupManager tổng hợp hoạt động, scene renderer xét activity của chính scene.

Host chưa hỗ trợ capability dùng adapter unavailable/no-op có trạng thái rõ ràng, không để screen tự kiểm tra `isMainApp`. Baseline là main app; extension/test là điểm mở rộng, không phải yêu cầu tạo thêm target. Config feature và host capability quyết định bật manager tại composition. Binding chỉ chuyển tiếp system API/event, không resolve repository, trả DIContainer hoặc điều hướng feature.

`NetworkArguments` là value cấu hình app/environment được dựng P0: base endpoints, app version, timeout/retry defaults, transport/security configuration cần cho backend đích. Credential và authenticated client thuộc account generation; auth client trước login được cấp riêng cho SessionManager. Thay đổi network policy runtime đi qua dependency observable riêng, không sửa credential trong một global arguments object. Không log credential/secret. [NetworkInitializationArguments gốc](../../../submodules/TelegramCore/Sources/Network/Network.swift) còn chứa stream và hook đặc thù Telegram; chỉ fork capability thực sự cần, không copy apiId/apiHash/VoIP fields mặc định.

## 2. PresentationConfig: chính sách chung, layout theo scene

`PresentationConfig` là immutable snapshot có `revision`, gồm theme/language preference, content density/spacing, split width preferences, tab policy và motion quality policy. `PresentationConfigStore` app-scoped giữ snapshot + ordered broadcast updates; có defaults P0 và đọc persisted settings P1. Remote config nếu có cập nhật sau, không chặn startup mặc định. Account preference overrides được gắn theo generation và gỡ khi logout, không rò sang account đăng nhập tiếp theo.

Pipeline: app config + account overrides hợp lệ + scene traits/bounds/safe area/keyboard → `ScenePresentationEnvironment` → RootController/coordinator/screens/renderers. Một revision chung có thể tạo layout khác nhau ở hai cửa sổ. Không lưu width, current presenter, selected item hoặc global `isCompact` trong PresentationConfig. System accessibility constraints được kết hợp vào effective policy, không bị config app vô hiệu hóa.

WindowController giữ environment và subscription theo scene. Update trên MainActor, coalesce revision; layout-only update không tạo lại account/feature graph, không reset route/draft, không chạy lại network action. Nếu navigation/split đang transition thì lưu revision đích mới nhất và reconcile sau completion/cancellation. Config width chỉ là preference cho UIKit; không ép scene bounds. Loại container stack/list-detail ổn định trong feature lifetime; thay đổi loại thật sự cần coordinator rebuild ở thời điểm an toàn, không thực hiện trong observer layout.

## 3. Service catalog và thời điểm khởi tạo

P0–P5 theo [DI overview §3](di-overview.md#3-launch-khác-với-runtime-liên-tục). Eager là thời điểm tạo facade/controller nhẹ; `start/prepare` là hoạt động riêng. Lazy không có nghĩa sẵn sàng ngay hoặc không cần owner.

| Dependency | Scope / bên giữ | Tạo và start mặc định | Phần được lazy / điều kiện |
| --- | --- | --- | --- |
| ApplicationBindings, NetworkArguments | App / DIContainer | P0 eager; bind system observers P1 khi cần | Capability không có trên host trả unavailable |
| PresentationConfigStore | App / DIContainer | P0 defaults; P1 đọc local, subscribe | Remote fetch sau launch; có defaults/degraded state |
| SessionManager, LaunchController | App / DIContainer | P0 dựng; runtime gọi P1/P2/P3 | Không tạo lại theo scene/login |
| ApplicationActivity, WakeupManager | App / DIContainer | P0 facade; P1 observers; bind account work P3 | Nhu cầu background quyết định work, không screen access |
| PushRegistrationService, ApplicationEventRouter | App / DIContainer | P0 facade; P1 nhận token/external events; bind account khi P4 | Remote register retry độc lập; không block account UI |
| AppLockService | App / DIContainer | P0 facade; P1 đọc policy/observe | Lock UI/covering riêng scene, tạo khi cần |
| Account storage + authenticated network/repository | Account / UserContextImpl | P3 mở/migrate/nạp dữ liệu tối thiểu trước ready | Kết nối vật lý do work policy; không đòi internet cho mọi local screen |
| AccountConfiguration/entitlements | Account / UserContextImpl | P3 seed cache/default và start updates | Refresh network không thiết yếu chạy nền; readiness lỗi rõ ràng |
| DownloadedMediaStoreManager + FetchManager | Account / UserContextImpl | P3 eager sau storage; start bookkeeping/resume work được phép | Download/decode bytes theo request; UI không phải nơi khởi chạy manager |
| PrefetchManager | Account / UserContextImpl | P3 dựng và đăng ký policy một lần nếu enabled; scheduler tiếp tục P5 | Heavy prefetch chỉ khi network/energy/activity/content demand cho phép; không chờ fetch xong để ready |
| MediaManager | App / DIContainer | P0 facade; P1 observe audio/activity; bind account khi dùng | Player/decoder/audio activation ở lần play; không kích hoạt audio chỉ vì app launch |
| MediaOverlayCoordinator/controller | Scene × generation / AuthorizedApplicationContext | Tạo lazy khi có media cần hiển thị | Detach khi scene đóng; playback theo media policy riêng |
| IAPManager | App / DIContainer | P0 facade; P1 transaction observation nếu IAP enabled | Product catalog/storefront UI/purchase flow khi mở shop; không lazy toàn listener |
| AccountPurchaseService | Account / UserContextImpl | P3 bind verified events/entitlements theo identity | Purchase request khi user thao tác; không giữ presenter |
| AdsManager | App / DIContainer | Facade lazy tại nhu cầu placement đầu tiên | SDK prepare/load sau enabled + SDK prerequisites; không chặn P1/P3, không giữ scene UI lâu dài |
| AdPlacement / ad presentation | Scene × generation hoặc request / feature coordinator | Lazy theo placement và thao tác | Loaded ad hết hạn/invalidate phải bỏ; callback/reward kiểm tra account gốc |
| AnimationEngine | App / DIContainer | P0 facade nhẹ; P1 setup policy + motion/power updates | Backend nặng/GPU/decoder lần đầu dùng, single-flight; fallback tĩnh khi unavailable |
| AccountAnimationCacheProvider | Account / UserContextImpl | P3 provider nhẹ với namespace/path/lifetime | Mở cache/tạo file/worker lần đầu dùng; kiểm tra generation sau await |
| AnimationRenderer/AnimationHost | Scene hoặc view / UI owner | Lazy tại consumer đầu tiên | Pause khi host ẩn/inactive; invalidate khi graph/host stop |
| Feature containers/coordinators | Feature × scene × generation / AppCoordinator | P4 tạo shell cho tab cần có | Screens/subflows và nội dung nặng theo route, không duplicate account service |

Đây là baseline có điều kiện: feature IAP/ads/prefetch bị tắt không khởi động SDK tương ứng. Nếu sản phẩm cần quảng cáo đã tải cho placement đầu, warmup có deadline sau P4 là chính sách riêng; không tự nâng thành launch blocker. Một factory chưa được gọi không có side effect. Service đã tạo vẫn có thể idle; UI luôn xử lý loading/error/unavailable của phần async lazy.

## 4. Khai báo mẫu trong DIContainer

Đoạn Swift sau là **pseudocode của composition**: các protocol, helper và initializer là hợp đồng dự kiến, chưa có implementation để build. Chỉ minh họa subgraph service được yêu cầu; graph runtime/route/cleanup đầy đủ theo DI overview. App facade init không mở disk/network/SDK. `prepareApplication` của LaunchController start app services; `prepareAccount` gọi factory và `UserContext.prepare/start`, rollback khi lỗi/hủy. UserContextImpl phải giữ lifecycle của service được inject thay vì tự dựng lại chúng.

```swift
@MainActor
final class DIContainer {
    let bindings: ApplicationBindings
    let networkArguments: NetworkArguments
    let presentationConfig: PresentationConfigStore
    let activity: ApplicationActivity
    let wakeupManager: WakeupManager
    let mediaManager: MediaManager
    let iapManager: IAPManager
    let animationEngine: AnimationEngine

    private let networkFactory: NetworkClientFactory
    private let accountStoreFactory: AccountStoreFactory
    private let adsSDKFactory: AdsSDKFactory
    private let features: FeatureConfiguration
    private var cachedAdsManager: AdsManager?

    init(bindings: ApplicationBindings,
         networkArguments: NetworkArguments,
         initialPresentation: PresentationConfig,
         features: FeatureConfiguration,
         adsSDKFactory: AdsSDKFactory,
         animationBackendFactory: AnimationBackendFactory) {
        self.bindings = bindings
        self.networkArguments = networkArguments
        self.features = features
        self.adsSDKFactory = adsSDKFactory

        let config = PresentationConfigStoreImpl(
            initial: initialPresentation, persistence: bindings.preferences)
        let activity = ApplicationActivityImpl()
        let media = MediaManagerImpl(
            audio: bindings.audio, activity: activity)

        self.presentationConfig = config
        self.activity = activity
        self.mediaManager = media
        self.wakeupManager = WakeupManagerImpl(
            activity: activity,
            backgroundTasks: bindings.backgroundTasks,
            mediaActivity: media.activity)
        self.networkFactory = NetworkClientFactory(
            arguments: networkArguments, transport: bindings.transport)
        self.accountStoreFactory = AccountStoreFactory(paths: bindings.paths)
        self.iapManager = IAPManagerImpl(
            client: StoreKitClientImpl(),
            transactionInbox: TransactionInbox(paths: bindings.paths),
            enabled: features.iapEnabled)
        self.animationEngine = AnimationEngineImpl(
            policy: config.motionPolicy,
            accessibility: bindings.motion,
            power: bindings.power,
            backendFactory: animationBackendFactory)
    }

    // MainActor chỉ serialize construction nhẹ, không chạy disk/GPU trên UI thread.
    func adsManager() -> AdsManager {
        if let manager = cachedAdsManager { return manager }
        let manager = AdsManagerImpl(
            enabled: features.adsEnabled, sdkFactory: adsSDKFactory)
        cachedAdsManager = manager
        return manager  // SDK chưa start; prepare/load có readiness riêng.
    }

    // Lifetime do runtime tạo trước async work để logout có thể invalidate ngay.
    func makeUserContext(auth: AuthenticatedAccount,
                         lifetime: AccountLifetime) async throws -> UserContextImpl {
        try lifetime.requireValid()
        let store = try await accountStoreFactory.openAndMigrate(auth.accountID)
        do {
            try lifetime.requireValid()
            let network = networkFactory.makeAuthenticatedClient(
                credentials: auth.credentials, lifetime: lifetime)
            let repository = AccountRepositoryImpl(
                store: store, network: network, lifetime: lifetime)
            let configuration = AccountConfigurationImpl(
                repository: repository, lifetime: lifetime)
            let mediaStore = DownloadedMediaStoreManagerImpl(store: store)
            let fetch = FetchManagerImpl(
                network: network, mediaStore: mediaStore, lifetime: lifetime)
            let prefetch = PrefetchManagerImpl(
                enabled: features.prefetchEnabled,
                fetchManager: fetch,
                configuration: configuration,
                activity: activity,
                power: bindings.power,
                lifetime: lifetime)
            let purchases = AccountPurchaseServiceImpl(
                accountID: auth.accountID,
                transactions: iapManager.verifiedTransactions,
                repository: repository, lifetime: lifetime)
            let animationCache = AccountAnimationCacheProvider(
                basePath: store.animationCachePath, lifetime: lifetime)

            return UserContextImpl(
                accountID: auth.accountID, lifetime: lifetime,
                store: store, repository: repository,
                configuration: configuration,
                mediaStore: mediaStore, fetchManager: fetch,
                prefetchManager: prefetch, purchases: purchases,
                animationCache: animationCache,
                wakeupManager: wakeupManager)
        } catch {
            await store.close()
            throw error
        }
    }

    // UserContext chỉ được phân phối tại composition boundary này.
    func makeHomeDI(user: UserContextImpl,
                    environment: ScenePresentationEnvironment,
                    sceneBindings: SceneBindings) throws -> HomeDIContainer {
        try user.lifetime.requireValid()
        return HomeDIContainer(
            repository: user.repository,
            fetchManager: user.fetchManager,
            configuration: user.configuration,
            lifetime: user.lifetime,
            presentation: environment,
            makeAnimationHost: { [engine = animationEngine,
                                 cache = user.animationCache,
                                 lifetime = user.lifetime] in
                try lifetime.requireValid()
                return engine.makeHost(environment: environment,
                                       cache: cache, lifetime: lifetime)
            },
            present: sceneBindings.present,
            media: mediaManager)
    }

    func makeSettingDI(user: UserContextImpl,
                       environment: ScenePresentationEnvironment,
                       sceneBindings: SceneBindings) throws -> SettingDIContainer {
        try user.lifetime.requireValid()
        return SettingDIContainer(
            accountSettings: user.repository.settings,
            purchases: user.purchases,
            presentationConfig: presentationConfig,
            presentation: environment,
            lifetime: user.lifetime,
            present: sceneBindings.present)
    }
}
```

Không có `start()` trong constructor mẫu. Account store factory chịu rollback tài nguyên mở dở nếu chính `openAndMigrate` throw; phần `catch` xử lý lỗi sau khi mở thành công. LaunchController chịu cleanup graph đã trả về nếu `prepare/start` tiếp theo fail hoặc attempt bị thay thế. Account init phải không khởi chạy task unowned; nếu implementation khác có side effect sớm, phải đăng ký rollback ngay tại điểm phát sinh.

Composition root tạo concrete platform/vendor adapters rồi truyền vào DIContainer (hoặc override typed dependency khi test). `SceneBindings.present` phải là callback tới scene presenter qua weak reference và kiểm tra uiGeneration/lifetime; không capture WindowController mạnh tạo vòng giữ. Các factory trên không giữ current account toàn cục. Khi nối factory account vào LaunchController được DIContainer cache, trích factory giữ các dependency cụ thể thay vì closure capture `self.makeUserContext`; tránh vòng container → launch → factory → container. Với Ads, feature nhận `makeAdPlacement`/`loadAd` closure được inject; closure không trả DIContainer và được cấp request context + lifetime, không cho màn hình gọi `adsManager()` qua global.

Mẫu cố ý không dùng `lazy var` cho backend async. Ads facade được cache trên MainActor; backend.prepare phải coalesce concurrent callers. Account cache provider và engine backend provider giữ một initialization task trong isolation riêng, hủy/đóng kết quả lỗi thời sau await. Factory `makeHost` dựng host nhẹ; host có loading/static fallback khi backend/cache chưa ready, không block UI thread.

## 5. AnimationEngine: đăng ký, setup và teardown

Trong source, [AccountContextImpl](../../../submodules/TelegramUI/Sources/AccountContext.swift) dựng `DCTAnimationCacheImpl` theo đường dẫn media account và `DCTMultiAnimationRendererImpl`, cập nhật renderer theo experimental settings. `AnimationEngine` là abstraction đích được đề xuất, không phải type có sẵn vừa tìm thấy trong Telegram.

Phân lớp mặc định:

- App `AnimationEngine`: facade/policy, typed backend factory, quản lý cache backend có thể dùng chung an toàn. Không chứa view/layer/current scene hoặc route.
- Account `AccountAnimationCacheProvider`: cache nội dung user theo namespace account, có lifetime/generation cho in-flight read/write. Có thể reuse dữ liệu disk account hợp lệ giữa các lần login theo policy, nhưng không reuse owner/task cũ.
- Scene/view `AnimationHost` và renderer: layer/view targets, display timing/visibility, transition handles. Không dùng chung renderer có mutable UI state giữa hai scene.

Setup theo thứ tự:

1. P0 inject `AnimationBackendFactory`, motion/power capabilities và policy từ PresentationConfigStore. Tạo facade nhẹ; backend có thể là UIKit/Core Animation hoặc decoder/render backend cụ thể được chọn tại composition.
2. P1 `animationEngine.start()` đọc snapshot motion/power và subscribe updates một lần. Không tạo GPU pipeline, display link hoặc render target chỉ vì app vừa mở.
3. P3 tạo account cache provider nhẹ sau storage; không scan/decode tất cả asset. Trước login, animation chỉ dùng bundled/public asset provider riêng, không lấy cache của account cũ.
4. Consumer đầu tiên P4/P5 gọi factory tạo host cho scene; backend/cache `prepare()` async single-flight. Host nhận effective scene environment, target identity và account lifetime khi dùng nội dung account.
5. Host chỉ chạy khi visible và scene policy cho phép; áp dụng Reduce Motion, power policy, memory pressure. Config update đổi policy/layout an toàn, không khởi động animation nghiệp vụ lại từ đầu theo mỗi revision.
6. Host stop/invalidate thì cancel callback/display timing và detach layer/view. Logout invalidate cache operations/hosts của generation cũ; engine app vẫn sống. Backend idle có thể nhả tài nguyên nặng và dựng lại khi cần; host A dừng không dispose backend đang phục vụ B.

Engine không thay navigation/split delegate, không tự push/pop hoặc commit route. Native navigation transition vẫn do UIKit/coordinator sở hữu. Nếu dùng engine tạo custom animator, cung cấp adapter qua navigation delegate và reconcile cancellation như window/navigation doc; callback animation chỉ có hiệu lực với scene, uiGeneration và transitionID hiện tại.

Backend chưa chốt; không mặc định bắt buộc Metal/Lottie hoặc copy DCT engine Telegram. Điều cần giữ là dependency rõ, cập nhật policy runtime, cache đúng scope và cleanup đúng owner. Reduce Motion có cả giá trị hiện tại và notification thay đổi để adapter theo dõi. [Apple UIAccessibility](https://developer.apple.com/documentation/uikit/uiaccessibility/)

## 6. MediaOverlay: tách playback khỏi cây UI

[MediaManager gốc](../../../submodules/TelegramUI/Sources/MediaManager.swift) giữ overlay manager; [OverlayMediaManager gốc](../../../submodules/AccountContext/Sources/OverlayMediaManager.swift) attach một controller. Cách giữ một controller này phải thay khi có nhiều scene.

- MediaManager app sở hữu playback/audio arbitration; media request gắn accountID + generation. Playback không phụ thuộc màn hình list/detail còn sống.
- AuthorizedApplicationContext tạo `MediaOverlayCoordinator` lazy theo scene. Coordinator giữ `OverlayMediaController: UIViewController` thuần UIKit và subscription playback; app manager không giữ controller mạnh.
- Khi chuyển inline ↔ overlay, coordinator của scene thực hiện detach/attach view hoặc tạo renderer mới từ playback state, giữ vị trí phát. Không gắn cùng view/controller vào hai parent hoặc hai scene. Baseline chỉ một visual host được chỉ định cho một playback tại một thời điểm; chuyển host là thao tác có identity rõ ràng.
- Resize cập nhật frame/safe area từ ScenePresentationEnvironment. Hit-testing chỉ bắt vùng player/control, không che nút đóng modal/quảng cáo. Ưu tiên overlay trong main UI tree; overlay window chỉ khi thật sự cần và luôn cùng scene.
- Scene đóng: detach host và callback; audio có thể tiếp tục nếu policy/background capability cho phép. Logout: dừng playback thuộc account cũ và gỡ mọi host của generation đó; không dựa vào deinit của một scene.
- Picture in Picture nếu triển khai phải qua adapter có owner và restore-to-scene policy; không suy ra rằng custom overlay tương đương PiP hệ thống. Chi tiết SDK/API PiP không nằm trong baseline hiện tại.

## 7. IAP và Ads: service dùng chung, trình bày đúng scene

Source [InAppPurchaseManager](../../../submodules/InAppPurchaseManager/Sources/InAppPurchaseManager.swift) đăng ký payment queue observer trong init và gắn engine account. Target tách app observation khỏi account attribution. Nếu dùng StoreKit 2, start transaction listener ở P1; không đợi mở shop. Kết quả mua trực tiếp và transaction updates phải vào cùng xử lý verify/deduplicate/durable delivery; updates không phải nguồn duy nhất cho mọi purchase. [Apple Transaction.updates](https://developer.apple.com/documentation/storekit/transaction/updates)

IAPManager giữ app transaction inbox/verification, catalog lazy và operation identity. AccountPurchaseService bind account gốc của transaction/purchase intent với backend entitlement; không gán một transaction hoàn tất muộn cho `currentUserContext` bất kỳ. Khi chưa đủ thông tin account, giữ pending reconciliation có identity, không grant nhầm hoặc finish bỏ mất xử lý. Finish theo hợp đồng verified delivery/persistence của sản phẩm, không chỉ vì UI đã đóng. Login refresh/reconcile entitlement; logout gỡ account binding nhưng không tắt app listener. Paywall, purchase presentation và các callback UI thuộc scene đang thao tác.

AdsManager là adapter đích, chưa chọn SDK và không tuyên bố fork một AdsManager Telegram cụ thể. App facade quản lý SDK readiness/loading/error và policy enabled; SDK init lazy theo catalog. Feature giữ ad placement/request có sceneID, account generation nếu có, placementID và expiration. Present yêu cầu presenter hợp lệ của scene foreground, account/UI chưa invalidate và không xung đột modal/transition. Callback đóng/reward không được route hoặc ghi vào account mới. Không để app manager lưu presenter mạnh; giải phóng SDK presentation delegate/loaded ad khi placement kết thúc theo adapter contract.

## 8. Kiểm chứng implementation cần thực hiện

1. Đếm constructor/start/stop theo scope và generation: thêm scene không tạo thêm FetchManager, PrefetchManager, IAP listener hoặc app motion observer.
2. Đồng thời yêu cầu ads/backend/cache chỉ tạo một instance/task trong scope; lỗi/cancel cho phép retry đúng, không publish kết quả đã invalidate.
3. Không mở shop vẫn nhận transaction update; purchase hoàn tất sau logout không grant cho account mới. Catalog offline không chặn root UI.
4. Prefetch phản ứng config/power/network; fetch explicit và prefetch background có ưu tiên/phạm vi hủy riêng, không hủy download user đang cần chỉ vì prefetch bị tắt.
5. Hai scene có revision config chung nhưng bounds/layout riêng; resize hoặc motion update không nhân đôi render/network action.
6. Animation trước login không chạm account cache; logout trong decode/write loại kết quả cũ; renderer A stop không dừng B.
7. Inline/overlay chuyển host giữ vị trí phát, không hai parent; scene close và logout có hành vi playback khác nhau như policy.
8. Ads callbacks, purchase UI và media restore không present vào scene đã đóng hoặc qua generation cũ.

Các kiểm chứng trên là tiêu chí cho codebase đích, chưa được chạy bằng source mẫu trong tài liệu này.
