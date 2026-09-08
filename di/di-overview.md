# DI overview — một account đăng nhập tại một thời điểm, nhiều scene

Cập nhật: 2026-09-08. Đây là kiến trúc đích lấy cảm hứng từ Telegram, chưa phải implementation đã kiểm thử. Deployment target: iOS/iPadOS 18.0+, UI thuần UIKit.

## 1. Quyết định nền tảng

- `AppDelegate` là entry point của composition root: tạo một `DIContainer`, dùng factory của nó tạo và giữ một `SharedApplicationContext` cho app.
- `DIContainer` đăng ký service và phụ thuộc bằng property/factory có kiểu rõ ràng, chọn implementation và quản lý scope. Không dùng static singleton hoặc global `resolve`; không inject nguyên container/context lớn vào feature hoặc màn hình.
- Giữ `UserContext` / `UserContextImpl`: hợp đồng / implementation đại diện account đang hoạt động và tài nguyên của account. Tối đa một context được công bố hoạt động, dùng chung giữa các scene. Không đổi tên thành `UserSession`.
- Account ID không đủ nhận diện một lần đăng nhập: `UserContext` có `generation`/lifetime token nội bộ. Logout rồi login lại cùng account tạo context và generation mới; không reuse công việc hoặc callback cũ.
- Bỏ `SharedContext` / `SharedContextImpl` khỏi baseline. DIContainer chỉ thay phần composition/cấp dependency; hành vi runtime của context gốc được chuyển sang các service có owner rõ ràng, không biến thành side effect của container. Một account đăng nhập không làm mất nhu cầu wakeup, push, media, cấu hình động hoặc platform bindings.
- `SharedApplicationContext` là nơi duy nhất commit chuyển trạng thái account. `SessionManager` xử lý xác thực/credential; `LaunchController` thực hiện bootstrap được giao; `WakeupManager` điều phối hoạt động liên tục sau bootstrap.
- Một `AppCoordinator` cho mỗi scene × generation, giữ các feature coordinator. UI, route, draft, presenter và renderer riêng scene; account service dùng chung.
- `HomeDIContainer`, `SettingDIContainer` nhận dependency cụ thể và cung cấp factory. Coordinator quyết định khi nào tạo màn hình/điều hướng; container không giữ route hoặc điều hướng.

`SharedContext` chỉ được cân nhắc lại nếu xuất hiện hợp đồng capability hẹp có consumer cụ thể; không thêm lại một túi service tổng hợp. `ApplicationBindings` là adapter platform và `PresentationConfig` là state cấu hình, không phải tên thay thế cho SharedContext.

## 2. Thành phần và hợp đồng

| Thành phần | Trách nhiệm | Scope / owner |
| --- | --- | --- |
| `DIContainer` | Dựng dependency, cache app service, cung cấp typed factories | App; AppDelegate giữ |
| `ApplicationBindings` / platform implementation | API/capability host: paths, notification token, background task, accessibility, device signals | App; DIContainer giữ; service nhận interface hẹp cần dùng |
| `NetworkArguments` | Cấu hình network: environment, endpoint, version, timeout policy; không giữ credential account hiện tại | App/configuration value |
| `PresentationConfig` + `PresentationConfigStore` | Snapshot có revision và updates chính sách theme/layout/motion toàn app | App; DIContainer giữ store |
| `SharedApplicationContext` | Restore/login/logout commands, transition identity, current UserContext và broadcast state tới mọi scene | App; AppDelegate giữ; không giữ UI |
| `SessionManager` | Restore/authenticate, credential storage, auth-attempt identity, remote invalidation | App; DIContainer giữ; không tự publish UI-ready |
| `LaunchController` / `LaunchControllerImpl` | Bootstrap app/account, progress, rollback khi lỗi/hủy; không chọn scene/root UI | App; DIContainer giữ; SharedApplicationContext điều phối |
| `LaunchControllerState` | Tiến độ từng launch attempt; không phải nguồn xác thực thứ hai | Value gắn attemptID, được runtime đưa vào state công bố |
| `UserContext` / `UserContextImpl` | Account identity, generation/lifetime, account services và start/invalidate/stop | Một lần account hoạt động; SharedApplicationContext giữ |
| `ApplicationActivity` + `WakeupManager` | Tổng hợp scene activity, presence, network work và nhu cầu nền | App; đăng ký account work theo generation |
| `PushRegistrationService`, `IAPManager`, `MediaManager` | Cơ chế chung của app; bind dữ liệu account khi phù hợp | App; không giữ root/presenter toàn cục |
| `AdsManager`, `AnimationEngine` | Adapter/facade khai báo ở DI; eager/lazy theo service catalog | App; renderer/placement riêng scene |
| `SceneDelegate` / `WindowController` | Nhận runtime/factory tại bootstrap, giữ window và context UI riêng | Scene |
| `SceneBindings`, `ScenePresentationEnvironment` | Platform presentation theo scene; kết hợp config chung với traits/layout | Scene; WindowController giữ |
| `AuthorizedApplicationContext` | Giữ UserContext và AppCoordinator; start/stop graph UI | Scene × generation |
| `AppCoordinator` / feature coordinators | Chọn tab, route liên feature / route và stack nội bộ | Scene × generation / feature × scene × generation |
| `HomeDIContainer`, `SettingDIContainer` | Factory coordinator/screen và dependency feature | Feature × scene × generation |

Tên chuẩn: `LaunchController`, `LaunchControllerImpl`, `LaunchControllerState`, `PrefetchManager`, `FetchManager`, `NetworkArguments`, `AdsManager`, `IAPManager`, `AnimationEngine`. `IAPManager` là tên đích cho vai trò in-app purchase; không yêu cầu copy nguyên `InAppPurchaseManager` gốc. Các manager mới là hợp đồng thiết kế, không khẳng định source Telegram có type cùng tên. Không tự động tạo cặp protocol/Impl cho mọi service; giữ hai cặp UserContext và LaunchController đã được chọn.

## 3. Launch khác với runtime liên tục

`LaunchController` là service bootstrap của ứng dụng, không phải UIViewController và không phải launch screen của iOS. I/O/network chạy bất đồng bộ; UI waiting của mỗi scene hiển thị trong khi chờ, không chặn callback khởi động của hệ điều hành.

| Bước | Thời điểm / chủ thể | Điều kiện hoàn tất |
| --- | --- | --- |
| P0 — composition | AppDelegate tạo DIContainer | Có bindings, arguments, config mặc định và facade nhẹ; constructor không tự mở mạng hoặc present UI |
| P1 — app bootstrap | Runtime gọi `LaunchController.prepareApplication()` một lần | Nạp config local cần thiết; start app observers/IAP listener, push/activity/wakeup/animation policy đúng một lần; không chờ catalog/ads/GPU |
| P2 — restore/authenticate | Runtime gọi SessionManager | Có credential hợp lệ hoặc signedOut; request gắn attemptID, không restore lại cho mỗi scene |
| P3 — account bootstrap | Runtime giao `LaunchController.prepareAccount(auth, generation)` | Mở/migrate storage, dựng graph bằng factory inject, nạp initial config tối thiểu, prepare/start service bắt buộc |
| P4 — publish và UI | Runtime commit P3; từng WindowController dựng graph | Kiểm tra attempt/generation còn hợp lệ; UserContext ready; scene chuẩn bị root/tab đầu tiên rồi gắn window |
| P5 — hoạt động liên tục | WakeupManager và các service đã start | Theo dõi activity, config, token, task; không kết thúc cùng launch |

Nếu cold start chưa login, P2 kết thúc ở signedOut; P3 chỉ chạy sau login. Logout/login chạy lại phần account P3, không tạo thêm app observers P1. Một số app observer cần bắt đầu ngay khi P1 bắt đầu, không chờ restore/account. UI readiness không được phụ thuộc vào `viewDidAppear` của root chưa được gắn, tránh vòng chờ; không đợi mọi tab hoặc tất cả request mạng.

`LaunchControllerState` đề xuất: `idle`, `preparingApplication(step)`, `restoringAccount`, `preparingAccount(step, progress)`, `ready`, `failed(stage, retryable)`, `cancelled`, luôn gắn attemptID khi đang chạy. Restoring progress do runtime chuyển tiếp từ SessionManager; LaunchController không quyết định login/logout. Runtime công bố một nguồn trạng thái cho scene: `launching(progress)`, `signedOut`, `preparingAccount(progress)`, `authorized(UserContext)`, `endingAccount`, `failed(stage)`.

Runtime tuần tự hóa command nhưng không giữ một thao tác chờ I/O khiến logout không thể invalidate. Mỗi kết quả async kiểm tra lại attemptID trước commit. Actor/MainActor vẫn có thể interleave qua `await`. Graph đang prepare chưa được công bố; lỗi/hủy phải rollback subscriptions/tasks/storage đã mở. Lỗi service tùy chọn đưa service đó vào degraded state, không khóa launch toàn app. App startup chỉ retry bước thất bại, không nhân đôi observer đã chạy.

## 4. Composition và truyền dependency

1. AppDelegate giữ DIContainer và runtime do `makeSharedApplicationContext()` trả về. Container không cache ngược runtime.
2. Runtime nhận SessionManager, LaunchController và các thao tác account binding/cleanup cụ thể qua initializer. LaunchController nhận app startup dependencies và factory account, không tự chọn implementation.
3. UserContextImpl nhận account services qua initializer; giữ lifecycle của chúng. Không tự dựng app service, không giữ controller/window/presenter.
4. Tại ranh giới composition, factory được phép nhận UserContext để lấy identity và phân phối các service account. `HomeDIContainer` nhận `repository`, `fetchManager`, `configuration`, `accountLifetime`, factory renderer/presenter cần thiết; không nhận nguyên UserContext hoặc DIContainer.
5. SceneDelegate nhận shared runtime + scene factory qua bootstrap AppDelegate → SceneDelegate. WindowController đăng ký snapshot và updates trên main actor; late subscriber luôn nhận trạng thái hiện tại.
6. AuthorizedApplicationContext giữ reference UserContext cho lifetime UI, nhưng màn hình chỉ nhận dependency nó dùng. Scene đóng gỡ subscription và UI graph, không gọi `UserContext.stop()`.

Khi DIContainer cache LaunchController, factory account inject vào LaunchController phải capture các dependency cụ thể hoặc một AccountFactory không giữ DIContainer; tránh vòng `DIContainer → LaunchController → closure → DIContainer`. Tương tự, account registration trong app managers không capture mạnh UserContext nếu UserContext giữ ngược manager; dùng weak callback/token được hủy khi stop.

Đăng ký service nghĩa là khai báo property/typed factory và constructor arguments trong composition root, không bắt buộc DI framework hoặc registry động. Mẫu ở [service-runtime-implementation.md](service-runtime-implementation.md).

## 5. Ownership và scope

| Bên giữ | Giữ gì | Không làm gì |
| --- | --- | --- |
| DIContainer | App service và factory | Không cache current UserContext, scene, screen/coordinator |
| SharedApplicationContext | Current/preparing UserContext, transition task, subscription app | Không giữ UIKit tree; không nhân bản state login ở LaunchController |
| UserContextImpl | Account services, lifecycle registrations, lazy providers thuộc generation | Không giữ scene UI; không dùng accountID thay generation |
| WindowController | Window, SceneBindings/environment, login hoặc authorized graph, scene subscription | Không tắt account work khi scene đóng |
| AuthorizedApplicationContext | UserContext, AppCoordinator, UI cancellation registrations | Không clear cache/presence chung trong stop/deinit |
| AppCoordinator | TabBarController, feature coordinators | Không sửa stack của feature hoặc kết thúc account |
| Feature coordinator | RootController, feature DI container, route/model state | Container không cache ngược coordinator |
| Feature DI container | Dependency cụ thể và scoped providers được inject | Không giữ parent container chỉ để resolve service |
| Window/UIKit containers | Cây UI hiển thị | Tháo root và callbacks khi graph kết thúc |

App service có thể giữ registration/resource account có giới hạn khi đang bind; phải detach đúng generation khi logout. Presentation callback hướng về scene dùng weak reference hoặc registration token; token bị hủy khi scene đóng. Không dùng weak capture như cơ chế duy nhất invalidate account.

App, account và scene laziness có isolation rõ ràng. Một `lazy var` thông thường không giải quyết truy cập đồng thời. Construction nhẹ trên MainActor; async provider cần single-flight, cancellation và rollback nếu generation hết hiệu lực. `stop()` không truy cập lazy property chưa dùng chỉ để khởi tạo rồi dừng nó.

## 6. Runtime state, route và presentation

- Config/service cung cấp current snapshot + broadcast updates có thứ tự; mọi scene nhận state mới. Không dùng một luồng tiêu thụ mà event chỉ đến một scene. Subscribe và replay snapshot phải tránh khoảng trống mất update.
- ApplicationBindings cấp app và SceneBindings cấp scene thay platform hook trong context gốc. App services không tra global key window. ScenePresentationEnvironment tính layout từ PresentationConfig + bounds/safe area/traits của scene đó.
- External route có requestID, target account nếu có, scene policy và generation sau khi bind. ApplicationEventRouter chọn scene; scene inbox chờ account/UI ready, scene phù hợp và unlock, rồi giao AppCoordinator → feature. Revalidate trước delivery; route S1 không tự chuyển thành route S2.
- Account/lock state broadcast cho mọi scene. Yêu cầu permission, điều khoản, quảng cáo hoặc deep link có một scene xử lý theo chính sách; không broadcast thành nhiều lần present. Login UI riêng scene nhưng auth attempt được runtime điều phối để chỉ một kết quả được commit.
- WakeupManager nhận activity tổng hợp và nhu cầu sync/upload/media; một scene background không tắt work của scene active khác. Không còn scene active cũng không tự hủy công việc nền hợp lệ.

## 7. Logout, invalidation và cleanup

1. Runtime invalidate generation ngay, hủy bootstrap nếu có, chặn route, screen factory và commit nghiệp vụ mới của account cũ.
2. Công bố `endingAccount`; các scene dừng tương tác, tháo modal/media overlay/renderer cũ, stop UI graph và thay root an toàn trên MainActor. Privacy covering dùng khi chưa thể thay cây ngay trong transition.
3. UserContext stop account work, dispose subscriptions, hủy fetch/prefetch, detach wakeup/media/entitlement bindings và đóng storage sau khi công việc truy cập đã kết thúc. Cleanup cache/draft theo chính sách dữ liệu; không mặc định xóa mọi dữ liệu persistent.
4. Cleanup riêng xử lý credential, remote logout và push unbinding theo generation/backend contract; có timeout/retry, không chặn UI signedOut vô hạn khi offline. App IAP listener tiếp tục sống; kết quả giao dịch giữ identity gốc để reconcile đúng account.
5. Bỏ reference current context; scene mở muộn nhận signedOut. Login lại tạo generation mới. Chỉ tạo graph mới dùng cùng storage account sau khi owner cũ nhả tài nguyên xung đột; cleanup backend có thể còn chạy với identity cũ.

`invalidate()` có hiệu lực ngay; `stop()` idempotent và có thể hoàn tất bất đồng bộ. Lifetime check nằm tại commit dữ liệu/presentation; nếu có await giữa check và commit, cần check lại hoặc commit trong cùng miền đồng bộ không bị xen ngang. Cleanup cũ không được xóa credential, push binding hoặc resource mới của account login lại. Factory account cũ trả lỗi invalidated, không đọc current context để tạo màn hình cho account mới.

Không port nguyên `AuthorizedApplicationContext.deinit` Telegram: source tắt presence/service work và clear cache tại đó, trong khi target có nhiều scene dùng chung account. Các thao tác chung chuyển về UserContext/WakeupManager; deinit chỉ là lớp phòng vệ sau stop.

## 8. Mapping hành vi Telegram và thay đổi chủ động

| Source / vai trò cũ | Thiết kế đích |
| --- | --- |
| SharedAccountContextImpl dựng dependency lẫn duy trì runtime | DIContainer dựng graph; LaunchController bootstrap; service chuyên trách giữ subscriptions/work |
| SharedContext/SharedContextImpl trong thiết kế trước | Bỏ; chuyển từng capability có owner, inject dependency cụ thể |
| AccountContextImpl | UserContextImpl đại diện account + generation; giữ account lifecycle, loại UI reference |
| ApplicationBindings có getTopWindow/present/orientation toàn cục | ApplicationBindings app + SceneBindings/presenter đúng scene |
| PresentationData snapshot + stream | PresentationConfigStore và service config account; scene tính environment riêng |
| SharedWakeupManager | WakeupManager liên tục; không gộp vào LaunchControllerState |
| Fetch/prefetch và animation cache/renderer trong AccountContext | Giữ account work/cache; tách renderer và animation UI ra scene |
| Shared media overlay gắn một controller | MediaManager app; MediaOverlayCoordinator/controller riêng scene |
| Root navigation chung chứa tabs | Tab-first, stack riêng feature; hành vi back/cross-tab đặc tả riêng |

Source tham chiếu: [ApplicationBindings](../../../submodules/AccountContext/Sources/AccountContext.swift), [SharedAccountContextImpl](../../../submodules/TelegramUI/Sources/SharedAccountContext.swift), [AccountContextImpl](../../../submodules/TelegramUI/Sources/AccountContext.swift), [ApplicationContext](../../../submodules/TelegramUI/Sources/ApplicationContext.swift), [SharedWakeupManager](../../../submodules/TelegramUI/Sources/SharedWakeupManager.swift).

Một account cùng lúc và UIKit/native containers là quyết định của sản phẩm đích; không cam kết giữ nguyên mọi hành vi multi-account/custom navigation của Telegram. FeatureCoordinator là tên vai trò, không bắt buộc base class. Chưa có source implementation của kiến trúc đích trong thư mục tài liệu này.

## 9. Tài liệu liên quan và nghiệm thu

- [service-runtime-implementation.md](service-runtime-implementation.md): service catalog eager/lazy, ApplicationBindings, PresentationConfig, DI mẫu, media/ads/IAP và AnimationEngine.
- [window-navigation-overview.md](window-navigation-overview.md): UIKit containment, navigation và presentation theo scene.
- Sơ đồ tương lai dùng PlantUML, không xuất SVG; các file `.puml` dự kiến chưa có. Phải theo UserContext/generation, LaunchController và scope mới.

Nghiệm thu implementation:

1. Hai scene cùng restore/login không tạo hai account graph hoặc app observers; cùng app/account service instance, UI/state riêng.
2. Lỗi/hủy/timeout bootstrap rollback đúng; logout trong prepare không publish kết quả cũ; retry không chạy trùng observer.
3. Đóng scene không dừng account work; activity/wakeup xét scene khác và background work còn hợp lệ.
4. Logout/login cùng account loại callback/factory/cache-write cũ; cleanup S1 không ảnh hưởng binding S2.
5. Config mới đến mọi scene; môi trường layout có thể khác nhau; layout update không reset route/draft hoặc nhân đôi request.
6. External request giao đúng một scene, chờ readiness và bị hủy đúng khi account thay đổi.
7. Fetch/prefetch chạy đúng phase; ads/catalog/GPU không chặn launch; IAP observation không chờ mở paywall.
8. Animation/media có host riêng scene, tôn trọng activity/motion policy; đóng host không phá service dùng chung.
9. Factory nhận dependency thay thế khi kiểm thử; không screen nào tìm service qua AppDelegate/global context/resolve.
