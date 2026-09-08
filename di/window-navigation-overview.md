# Window, tab và navigation — UIKit cho iPhone và iPad

Tài liệu 02 trong bộ kiến trúc. Ngày: 2026-09-08.
Tiếp nối [di-overview.md](di-overview.md). Catalog service, bindings, media/IAP/Ads và AnimationEngine ở [service-runtime-implementation.md](service-runtime-implementation.md).

Trạng thái: thiết kế để triển khai, cập nhật ngày 2026-09-08; chưa có code UIKit được chạy kiểm thử. Baseline duy nhất: iOS/iPadOS 18.0+, UI thuần UIKit.

## 1. Quyết định cấu trúc

1. AppDelegate khởi tạo DIContainer và SharedApplicationContext. DIContainer lắp ráp dependency; SharedApplicationContext commit trạng thái account, giao bootstrap cho LaunchController và work liên tục cho WakeupManager theo tài liệu DI.
2. Giữ UserContext/UserContextImpl đại diện một account đăng nhập tại một thời điểm; mỗi lần login có generation mới. Mỗi scene có WindowController, AuthorizedApplicationContext, AppCoordinator và cây UI riêng. Bỏ SharedContext/SharedContextImpl; feature nhận dependency cụ thể.
3. Sau account bootstrap và UI readiness, Window.rootViewController là TabBarController. Trước đó scene hiển thị waiting/login/error. Không có navigation controller chung bọc ngoài tab bar.
4. Mỗi tab luôn có một `RootController: UIViewController` làm custom container ổn định. RootController chọn và giữ một child container theo cấu hình feature được inject: NavigationController cho stack hoặc SplitViewController cho list–detail.
5. TabBarController chỉ quản lý các tab RootController; không quyết định feature cần stack hay split. Feature DI container dựng graph theo cấu hình; RootController thực hiện lựa chọn/containment, feature coordinator thực hiện route.
6. Với feature list–detail, giữ SplitViewController(style: .doubleColumn) bên trong RootController cả khi compact. Resize để split collapse/expand, không thay split bằng navigation chỉ vì đổi kích thước.
7. Màn hình dùng UIViewController/UIView và các UIKit controls. Không dùng SwiftUI, UIHostingController hoặc NavigationStack.
8. ApplicationBindings cấp app không giữ window/presenter. SceneBindings và ScenePresentationEnvironment thuộc scene; PresentationConfig chung chỉ cung cấp chính sách, không chứa layout thực tế của một cửa sổ.

### Ràng buộc native cần biết

Apple mô tả split view thường là root window, không cho phép push split view vào navigation stack, và không khuyến nghị nhúng split view vào container khác trong đa số trường hợp. Thiết kế này chủ động đặt split view trong RootController của một tab để đáp ứng yêu cầu tab-first. Đây là sự kết hợp container có đánh đổi, không phải cấu trúc Apple khuyến nghị mặc định cho mọi app. Chỉ dùng ở tab có nhu cầu nhiều cột; kiểm thử tab bar/sidebar, safe area, modal và collapse/expand trên các OS được hỗ trợ trước khi phát hành. [UISplitViewController](https://developer.apple.com/documentation/uikit/uisplitviewcontroller)

Không push split view vào `NavigationController`; không push `UINavigationController` vào một navigation controller khác.

## 2. Thành phần ứng dụng và UIKit tương ứng

| Thành phần | Nền tảng / hợp đồng | Trách nhiệm |
| --- | --- | --- |
| `SceneDelegate` | `UIWindowSceneDelegate` | Nhận scene, shared runtime và factory được inject; tạo/giữ WindowController |
| `WindowController` | Class ứng dụng | Giữ main window và context UI hiện tại; thay root; quản lý presentation theo scene |
| `LaunchController` / `LaunchControllerImpl` | Service bootstrap, không phải UIViewController | Chuẩn bị app/account; WindowController hiển thị progress từ runtime, không tự launch account riêng |
| `SceneBindings` | Adapter platform theo scene | Presenter/URL/orientation/focus đúng UIWindowScene; callback không giữ vòng owner |
| `ScenePresentationEnvironment` | Observable state trên MainActor | Kết hợp PresentationConfig với account overrides, bounds/traits/safe area/keyboard của scene |
| `Window` | Subclass `UIWindow` | Điểm mở rộng window-level hit-testing khi cần; mặc định giữ xử lý native |
| `AuthorizedApplicationContext` | Class ứng dụng | Giữ UserContext và AppCoordinator; start/stop UI graph theo phiên |
| `AppCoordinator` | Class ứng dụng; `UITabBarControllerDelegate` | Một instance/scene/phiên; giữ tab bar và feature coordinators, chọn tab và chuyển route liên feature |
| `TabBarController` | Subclass `UITabBarController` | Chọn tab, tab bar/sidebar, áp dụng chính sách ẩn/hiện thanh tab |
| `HomeCoordinator`, `SettingCoordinator` | Feature coordinator; `UINavigationControllerDelegate`, thêm `UISplitViewControllerDelegate` khi có split | Route và state của feature; gọi factory của feature DI container; đồng bộ compact/expanded |
| `NavigationController` | Subclass `UINavigationController` | Hành vi navigation chung, bar policy và điểm mở rộng transition |
| `RootController` | Subclass `UIViewController` | Custom container gốc từng tab; chọn/giữ NavigationController hoặc SplitViewController theo cấu hình feature |
| `SplitViewController` | Subclass `UISplitViewController` | Cấu hình cột, width, preferred display mode và split behavior |
| `OverlayController` | Subclass `UIViewController`, chỉ khi cần overlay window | Nội dung phủ theo scene và chính sách vùng nhận touch |
| `MediaOverlayCoordinator` / `OverlayMediaController` | Coordinator và UIViewController thuần UIKit | Host media inline/overlay theo scene × generation; MediaManager dùng chung giữ playback |
| `AnimationHost` / renderer | Scene/view object | Target view/layer, visibility và animation handles; lấy backend qua AnimationEngine được inject |

Home và Setting là ví dụ feature, chưa chốt số lượng tab sản phẩm. FeatureCoordinator là tên vai trò, chưa bắt buộc có base class/protocol. HomeDIContainer và SettingDIContainer tạo dependency/màn hình; không điều hướng hoặc giữ route state.

## 3. Hai dạng tab

| Dạng | Cây controller bên trong TabBarController | Khi dùng |
| --- | --- | --- |
| Stack trực tiếp | `TabBarController → RootController → NavigationController → màn hình` | Form, tài khoản, luồng tuần tự không cần nhiều cột |
| Nhiều cột | `TabBarController → RootController → SplitViewController → NavigationController từng slot → màn hình` | Danh sách–chi tiết, duyệt nội dung |

Đối với tab nhiều cột, giữ RootController làm tab root và split controller làm child ổn định và cấu hình ba slot:

| Slot của split | Controller của ứng dụng | Nội dung |
| --- | --- | --- |
| `.compact` | `compactNavigation: NavigationController` | Root danh sách, rồi detail và các màn hình con được push |
| `.primary` | `primaryNavigation: NavigationController` | Danh sách hoặc bộ lọc trong giao diện mở rộng |
| `.secondary` | `detailNavigation: NavigationController` | Placeholder khi chưa chọn; detail và các màn hình sâu hơn khi đã chọn |

`.compact` là cây thay thế khi split collapse, không phải cột thứ ba được hiển thị cùng lúc. Chọn explicit compact controller để không phụ thuộc vào việc UIKit tự ghép các stack. Dùng `setViewController(_:for:)` của column-style split; không trộn các delegate collapse của classic split vào cách triển khai này. [Cột compact và transition](https://developer.apple.com/documentation/uikit/uisplitviewcontroller), [UISplitViewControllerDelegate](https://developer.apple.com/documentation/uikit/uisplitviewcontrollerdelegate)

Mỗi slot dùng một instance navigation riêng. Controller màn hình cũng riêng theo cây; chia sẻ model/session phù hợp, không gắn cùng UIViewController vào hai parent. Có thể dựng lazy và giải phóng cây không dùng khi đã lưu state.

### 3.1 Hợp đồng RootController

RootController nhận cấu hình có kiểu rõ ràng (stack hoặc list–detail) và child/factory tương ứng từ feature composition. Quyết định chỉ liên quan container trình bày; không chọn service, không lưu business route, không trở thành router thứ hai. Cấu hình này ổn định trong vòng đời feature; thay đổi nghiệp vụ thực sự cần chuyển loại container phải được coordinator điều phối ngoài transition.

Containment dùng API UIKit: addChild → gắn child.view và constraints → didMove(toParent:); khi tháo child gọi willMove(toParent: nil), tháo view rồi removeFromParent. RootController cần xử lý layout/safe area, appearance forwarding theo cơ chế UIKit, và chuyển tiếp status bar/home indicator/orientation policy tới child phù hợp. Không phát appearance callbacks hai lần nếu forwarding tự động vẫn bật. RootController sở hữu tabBarItem của tab. [Custom container của Apple](https://developer.apple.com/documentation/uikit/creating-a-custom-container-view-controller)

Lớp wrapper này tăng tính thống nhất của app, nhưng không làm mất đánh đổi split lồng trong tab. Cần kiểm thử thực tế việc forwarding, tab bar/sidebar, safe area, keyboard và split adaptation qua custom container.

### 3.2 Hợp đồng coordinator

- AppCoordinator giữ HomeCoordinator/SettingCoordinator; xử lý chọn tab, tab được chọn lại và route liên feature. Nó chuyển route nội bộ cho đúng feature coordinator.
- Feature coordinator giữ RootController và feature DI container; là nơi duy nhất sửa navigation stack và commit route của feature. AppCoordinator không đồng thời push/pop vào các stack đó.
- Feature coordinator nhận intent từ màn hình qua callback/API được inject; dùng DI factory dựng màn hình, rồi route trên navigation controller phù hợp. RootController chỉ quản lý containment.
- Mỗi navigation/split delegate có một owner rõ ràng là feature coordinator tương ứng. Nếu thêm child coordinator cho subflow, parent phân quyền rõ ràng; không ghi đè delegate hoặc cùng sửa một stack độc lập.
- Feature coordinator báo trạng thái hiển thị thanh tab lên AppCoordinator; AppCoordinator lấy policy của feature đang chọn và yêu cầu TabBarController áp dụng.

Đổi TabCoordinator cũ thành AppCoordinator một-một rồi thêm HomeCoordinator bên dưới sẽ để lại hai tầng cùng sở hữu route từng tab. Thiết kế này chuyển trách nhiệm từng tab sang feature coordinator và dùng AppCoordinator parent theo scene. Stack riêng từng tab là thay đổi chủ động so với navigation root chung Telegram, không cam kết giữ nguyên mọi hành vi gốc. Baseline: chọn tab khác giữ lịch sử; chọn lại tab đang chọn giao intent cho feature (mặc định giữ route, chỉ scroll-to-top khi đã ở list root); route tới detail hiện tại tránh push trùng, route tới item khác thay detail path; cross-feature route chỉ sửa feature đích. Modal chặn route phải được scene presenter đóng hoặc giữ route chờ theo policy, không push xuyên qua presentation đang chuyển tiếp.

## 4. Ai giữ object nào?

| Bên giữ | Object được giữ | Ghi chú |
| --- | --- | --- |
| SceneDelegate | WindowController, SharedApplicationContext | Shared runtime và factory được truyền vào; không tra global key window |
| WindowController | Main Window, AuthorizedApplicationContext hiện tại | Context UI có thể nil khi chưa login |
| WindowController | SceneBindings, ScenePresentationEnvironment, scene inbox và presentation subscriptions | Late subscriber nhận snapshot hiện tại; generation/uiGeneration kiểm tra trước commit UI |
| WindowController | Overlay Window tùy chọn | Chỉ khi cần lớp cửa sổ riêng trong cùng scene |
| Main Window | TabBarController sau login | Qua rootViewController; trước login là root chờ/login |
| AuthorizedApplicationContext | UserContext, AppCoordinator | UserContext dùng chung; UI riêng scene |
| AuthorizedApplicationContext | MediaOverlayCoordinator khi cần | Lazy scene × generation; stop UI không dừng playback chung trừ account invalidated |
| AppCoordinator | TabBarController, HomeCoordinator/SettingCoordinator | Điều phối tab và route liên feature |
| TabBarController | RootController của từng tab | Tab ở ngoài custom container và navigation |
| RootController | NavigationController hoặc SplitViewController | Một child container theo cấu hình feature |
| Feature coordinator | RootController, feature DI container, state điều hướng | AppCoordinator giữ coordinator sống; DI container không cache ngược coordinator |
| SplitViewController | Controllers cấu hình cho compact/primary/secondary | Không phải mọi cây đều hiển thị đồng thời |
| NavigationController | Các controller trong stack | UIKit quản lý stack và transition |
| Scene/view owner | AnimationHost/renderer | Lazy, không dùng chung view/layer/render state giữa các scene |

Các liên kết delegate được vẽ là weak/non-owning. Callback từ màn hình về coordinator dùng weak capture khi cần để tránh vòng giữ; không dùng deinit làm cơ chế duy nhất kết thúc công việc. UIKit mutation và điều phối UI chạy trên main actor.

`AuthorizedApplicationContext.stop()` hủy route/subscription/presentation/render host của scene, không gọi `UserContext.stop()`, clear cache chung hoặc tắt presence/service work. WindowController tháo root cũ để UIKit không tiếp tục giữ graph đã stop. Runtime account và WakeupManager sở hữu teardown account; scene disconnect chỉ unregister activity và UI của scene đó.

## 5. Các chế độ hiển thị và nơi kiểm soát

Các trục dưới đây độc lập: window level, tab selection, split arrangement và navigation depth không phải một enum chung.

### 5.1 Window / scene

| Chế độ hoặc hành vi | Chủ thể kiểm soát | Chính sách thiết kế |
| --- | --- | --- |
| Launch / login / preparing account / authorized / error | WindowController theo trạng thái từ SharedApplicationContext | LaunchController cung cấp progress; chờ account và UI tối thiểu ready; không dựng UserContext riêng theo scene |
| Main window | WindowController + UIWindow | `.normal`, root UI của scene; make key/visible phù hợp lifecycle |
| Overlay theo scene | WindowController + optional Window | Ưu tiên overlay trong cây view cho nhu cầu cục bộ; window riêng chỉ cho lớp phủ thực sự cần độc lập |
| Overlay window level | UIWindow | Level nhỉnh hơn main trong cùng scene khi cần; không có nghĩa phủ được UI hệ thống hoặc cửa sổ app khác |
| Resize, foreground/background | Hệ điều hành + UIWindowScene | App phản ứng qua lifecycle/traits/layout; không quyết định cửa sổ iPad luôn full screen |
| Sheet / form / full screen / popover | Presenting UIViewController + presentation controller | WindowController tìm presenter đúng scene; đây không phải các mode của UIWindow |

Overlay window không tự trở thành key chỉ để hiển thị thông báo. Nếu thực sự cần focus/input, phải quản lý và khôi phục key window. Window level không quyết định modal adaptation, orientation hay status bar. [UIWindow](https://developer.apple.com/documentation/uikit/uiwindow), [UIWindow.Level](https://developer.apple.com/documentation/uikit/uiwindow/level)

UI waiting/error do scene tạo, không đồng nhất với LaunchController (service) hoặc launch screen hệ điều hành. Root readiness không đợi `viewDidAppear` của root chưa gắn hoặc toàn bộ dữ liệu mạng. Callback ready phải kiểm tra generation và uiGeneration hiện tại; scene đóng hoặc logout giữa bootstrap không được gắn root cũ.

### 5.1.1 PresentationConfig và layout runtime

PresentationConfigStore phát snapshot/revision toàn app; ScenePresentationEnvironment kết hợp account overrides hợp lệ với traits, bounds, safe area, keyboard và accessibility của scene. Theme, density, spacing, split width preferences và motion policy có thể cập nhật trong runtime. Hai scene nhận cùng config nhưng không bắt buộc cùng layout/appearance hệ thống.

WindowController điều phối update trên MainActor; RootController áp dụng containment/layout, feature coordinator reconcile route projection và TabBarController áp dụng bar policy cho tab đang chọn. Không observer nào trở thành router thứ hai. Coalesce revision trong transition; sau completion/cancellation áp dụng revision mới nhất, giữ selection/draft/focus. Không tạo lại UserContext, không kích hoạt lại account request hoặc thay split ↔ navigation chỉ vì config/layout update. Giới hạn width/displayMode là preference cho native container, không cam kết ép hệ thống.

### 5.2 Tab bar

| Chế độ | API / owner | Chính sách |
| --- | --- | --- |
| Tab đang chọn | TabBarController | Selection riêng scene; giữ stack tab khác |
| Tab bar native | `mode = .tabBar` (iOS 18+) | Baseline cho bộ tab cố định; vị trí/appearance theo môi trường và OS |
| Tab/sidebar thích ứng | `mode = .tabSidebar` (iOS 18+) | Khả năng mở rộng khi sản phẩm cần; không bật mặc định cùng sidebar primary của split |
| Tự động | `mode = .automatic` | Hệ thống lựa chọn theo cấu hình; không bảo đảm bar luôn ở dưới |
| Ẩn/hiện tab bar | TabBarController, `setTabBarHidden(_:animated:)` (iOS 18+) | Một nơi duy nhất áp dụng kết quả chính sách; cập nhật sau chọn tab và sau transition |

Baseline: khi split collapsed, màn hình root hiện tab bar, màn hình detail có thể yêu cầu ẩn; khi expanded, duyệt detail trong cột giữ tab bar. Immersive viewer nên present full screen để không phải ẩn đồng thời nhiều loại sidebar. Tab không được chọn không được đổi visibility của tab bar đang hiển thị.

Không dùng đồng thời `hidesBottomBarWhenPushed` và cơ chế explicit ẩn bar cho cùng luồng. Với tab split, chọn explicit policy ở TabBarController, không giả định navigation lồng bên trong sẽ tự ẩn outer tab bar. `setTabBarHidden` điều khiển tab bar, không phải API chung để ẩn cả sidebar. Deployment target thống nhất iOS/iPadOS 18.0+; không triển khai fallback cho OS thấp hơn hoặc private API. [Tab/sidebar](https://developer.apple.com/videos/play/wwdc2024/10147/), [Ẩn tab bar](https://developer.apple.com/documentation/uikit/uitabbarcontroller/settabbarhidden(_:animated:))

### 5.3 Navigation

| Chế độ / thao tác | Chủ thể | Chính sách |
| --- | --- | --- |
| Root / pushed detail | NavigationController và Feature coordinator | Mỗi stack độc lập; back chỉ tác động stack đang tương tác |
| Interactive pop đang chạy | UIKit transition và delegate | Chặn thao tác route xung đột; không commit state khi gesture mới bắt đầu |
| Pop hoàn tất / bị hủy | Delegate `didShow` và transition coordinator | Đọc stack thực tế; khôi phục tab visibility nếu bị hủy |
| Navigation bar native | UINavigationController | Mặc định tận dụng back, title và split controls |
| Custom header UIKit nếu cần | Màn hình + NavigationController | Cung cấp back/sidebar actions, accessibility và safe area đúng |

Không thay delegate của gesture recognizer hệ thống một cách vô điều kiện. Custom interactive transition dùng API navigation delegate/animator/interaction công khai, được kiểm thử xung đột với scroll ngang và split gesture. Ẩn native navigation bar không thay đổi chủ thể quản lý stack. [UINavigationController](https://developer.apple.com/documentation/uikit/uinavigationcontroller), [Transition bị hủy](https://developer.apple.com/documentation/uikit/uiviewcontrollertransitioncoordinatorcontext/iscancelled)

### 5.4 Split view

| Trạng thái / cấu hình | Ý nghĩa |
| --- | --- |
| `isCollapsed == true` | Hiển thị compact tree; detail được push trong compactNavigation |
| `oneBesideSecondary` | Primary nằm cạnh secondary khi có không gian |
| `oneOverSecondary` | Primary phủ một phần secondary |
| `secondaryOnly` | Chỉ secondary hiển thị trong bố cục expanded; không đồng nghĩa collapse |
| `preferredDisplayMode = .automatic` | Baseline: UIKit chọn cách sắp xếp; app đọc actual `displayMode` |
| `preferredSplitBehavior` | Gợi ý tile / overlay / displace; khác với display mode |

`preferredDisplayMode` là yêu cầu ưu tiên, không phải bảo đảm. Dùng bounds, safe area, traits và trạng thái split thực tế; không rẽ nhánh chỉ bằng iPhone/iPad hoặc portrait/landscape. Triple-column và inspector không nằm trong baseline, chỉ bổ sung khi có nhu cầu nội dung. [DisplayMode](https://developer.apple.com/documentation/uikit/uisplitviewcontroller/displaymode-swift.enum), [Split view](https://developer.apple.com/documentation/uikit/uisplitviewcontroller)

## 6. Giữ state khi cửa sổ đổi kích thước

Feature coordinator là nơi duy nhất thực hiện route operation cho tab. Nó lưu selected item, route đã commit, trạng thái nội dung cần bảo toàn; UIKit callbacks cập nhật lại snapshot sau thao tác người dùng. Không chạy hai router có khả năng tự sửa qua lại.

| Sự kiện | Xử lý thiết kế |
| --- | --- |
| Chọn item khi compact | Dựng/push detail vào compactNavigation |
| Chọn item khi expanded | Thay detail root trong detailNavigation, giữ primary selection |
| Expand từ màn hình detail | Dựng primary và detail tree từ cùng route đã commit; giữ selected item và draft |
| Collapse khi đã chọn detail | Tái tạo compact stack `[list, detail, ...]` từ route đã commit |
| Collapse khi chưa chọn | Compact stack chỉ có list |
| User pop về list | Commit bỏ detail route; clear active selection theo policy baseline để lần expand không mở lại detail cũ |
| Resize trong interactive pop | Tránh rebuild stack đang transition; chờ kết quả/cancellation rồi áp dụng snapshot cuối cho layout đích |

Không kỳ vọng chỉ set `.compact` sẽ tự đồng bộ ba cây controller. Chuẩn bị projection tại các callback chuyển layout phù hợp, kiểm tra kết quả bằng delegate didCollapse/didExpand và navigation didShow. Không dồn toàn bộ logic vào didExpand nếu làm xuất hiện khung hình state cũ.

Scroll position/draft nằm ở model có identity ổn định theo scene/feature; không dựa vào việc controller cũ luôn sống. Khôi phục process cần lưu state có chọn lọc riêng, không serialize controller instances.

Gắn identity/revision cho projection operation và transition. Delegate callback từ cây không active, controller đã invalidate hoặc thao tác set stack phục vụ projection không được hiểu nhầm thành user pop để xóa selection. Model/coordinator giữ side effect nghiệp vụ; dựng lại compact/expanded controller chỉ bind state, không chạy trùng upload/fetch. Animation host riêng từng cây có visibility policy, không để cả cây ẩn tiếp tục render.

## 7. Touch, overlay và trình bày

- View-level hit-testing giải quyết vùng bấm hoặc vùng transparent; mặc định cho UIKit tìm view đích.
- Gesture policies đặt ở navigation/feature, không dùng window để quyết định mọi swipe.
- Overlay root cần định nghĩa vùng interactive; vùng còn lại passthrough nếu là overlay không modal. Không trả nil cho toàn window khi vẫn cần nhận touch ở controls.
- Cửa sổ overlay là instance khác nhưng cùng UIWindowScene; không lấy một window toàn cục cho mọi scene.
- Popover trên iPad phải có anchor hợp lệ theo presenter; layout sheet tuân thủ hệ thống.
- Quảng cáo full screen dùng presenter của scene đang tương tác; overlay không che controls đóng. AdsManager app-scoped được khai báo trong DI, facade/SDK lazy theo service catalog; placement/load/presentation thuộc feature × scene × generation. Chưa chọn SDK cụ thể.
- Status bar/orientation được xử lý qua controller và scene APIs. WindowController chỉ điều phối, không gán chúng thành thuộc tính window level.

### 7.1 Media overlay và animation

MediaManager dùng chung giữ playback/audio policy, không giữ OverlayMediaController toàn cục. AuthorizedApplicationContext tạo MediaOverlayCoordinator lazy cho scene khi cần. Host inline/overlay thuộc scene, chuyển host detach trước khi attach hoặc dựng renderer mới từ cùng playback state; không gắn cùng view/controller vào hai parent. Một playback có một visual host được chỉ định theo baseline, không tự nhân bản video UI sang scene khác.

Scene đóng gỡ host/subscription; audio có thể tiếp tục theo policy. Logout dừng media của account generation cũ và tháo host ở mọi scene. Overlay layout dùng ScenePresentationEnvironment; PiP nếu bổ sung có adapter và restore-to-scene policy riêng. Chi tiết [media service](service-runtime-implementation.md#6-mediaoverlay-tách-playback-khỏi-cây-ui).

AnimationEngine là facade app-scoped được setup policy P1, backend nặng lazy. Factory feature nhận `makeAnimationHost` có environment và account lifetime/cache provider; host/renderer thuộc scene/view. Không inject nguyên UserContext vào view để lấy renderer. Host pause khi không visible/scene inactive theo policy, stop khi graph kết thúc; không dispose backend app còn phục vụ scene khác. Engine không sửa navigation stack hoặc chiếm split delegate. Chi tiết [setup AnimationEngine](service-runtime-implementation.md#5-animationengine-đăng-ký-setup-và-teardown).

### 7.2 External route, app lock, permission, Ads và IAP

ApplicationEventRouter nhận URL/notification/yêu cầu UI, chọn một scene qua registration không sở hữu mạnh. Scene inbox giữ requestID + account/generation khi bind; chờ account/UI ready, scene thích hợp và unlock rồi chuyển AppCoordinator → feature. Revalidate ngay trước delivery; logout hủy route cũ. Không dùng global top window để tìm presenter.

Account/lock state broadcast cho mọi scene; permission/terms/deep link hoặc yêu cầu quảng cáo có một scene xử lý theo chính sách để tránh present lặp. AppLockService giữ policy/state, covering view/passcode UI riêng scene. Khi invalidate trong transition, chặn tương tác/che nội dung account ngay rồi tháo UI an toàn; không đợi callback dismiss cũ để quyết định generation còn hợp lệ.

IAPManager app-scoped nghe transaction từ P1; paywall/catalog lazy và UI mua gắn scene yêu cầu. Logout không hủy listener app; kết quả giao dịch reconcile với identity account gốc, không với current account bất kỳ. Ads placement, reward callback và callback purchase UI kiểm tra generation/uiGeneration; scene đóng không được present vào window khác tùy ý. [Hợp đồng IAP/Ads](service-runtime-implementation.md#7-iap-và-ads-service-dùng-chung-trình-bày-đúng-scene).

## 8. Sơ đồ dự kiến

Các file `ui-01-window-objects.puml`, `ui-02-compact-objects.puml`, `ui-03-expanded-objects.puml`, `ui-04-types-protocols.puml` chưa có trong workspace. Khi bổ sung phải mô tả UserContext/generation dùng chung, LaunchController service bootstrap, RootController là UIViewController container, AppCoordinator theo scene và feature coordinators bên dưới; bỏ SharedContext/SharedContextImpl. Phân biệt ApplicationBindings app với SceneBindings, config chung với layout scene, media/animation service với UI host. Dùng PlantUML, không xuất SVG. Chưa có kết quả kiểm tra cú pháp sơ đồ hoặc runtime UIKit cho thiết kế cập nhật.

## 9. Tiêu chí nghiệm thu implementation sau này

1. Root main window sau login là TabBarController; mỗi tab chứa RootController: UIViewController rồi navigation hoặc split. Không có navigation bọc ngoài tabs hoặc split bị push vào stack.
2. Chuyển tab giữ lịch sử riêng; thao tác ở tab ẩn không thay bar của tab hiện tại.
3. Swipe-back hoàn tất/hủy khôi phục đúng màn hình, tab bar và snapshot route.
4. iPad rộng/hẹp, resize và rotation không mất selection, draft, keyboard focus cần thiết; không tạo hai parent cho một controller.
5. Hai scene không dùng chung UI controllers, route state hoặc overlay windows.
6. Logout dừng công việc và thay UI ở mọi scene, không để callback cũ present màn hình.
7. Custom header có back/sidebar action, VoiceOver và vùng chạm phù hợp.
8. Nested split-tab phải kiểm tra trên OS tối thiểu và OS phát hành mục tiêu; nếu native behavior không đạt, đánh giá lại riêng tab đó trước khi mở rộng.
9. Một AppCoordinator/scene/phiên, một feature coordinator/feature/scene; AppCoordinator không sửa trực tiếp stack của feature.
10. RootController forwarding đúng lifecycle, safe area, status bar và layout của child; mỗi child chỉ có một parent.
11. Build target iOS/iPadOS 18.0+, màn hình UIKit; DI factory tạo graph và coordinator xử lý route theo tài liệu DI.
12. Config revision đổi khi resize/swipe-back không mất draft/focus, không reset route hoặc chạy trùng side effect; callback cây ẩn không commit sai.
13. Scene disconnect không tắt account presence/fetch/prefetch; media/animation detach đúng host. Logout invalidate host và callback của account cũ ở mọi scene.
14. Deep link/permission/ads request đến đúng một scene, chờ readiness/unlock; callback ready/presentation sau logout không dựng lại UI cũ.
15. IAP observer không đợi paywall; Ads/GPU/catalog lazy không block UI launch. Platform bindings và scene presenter có thể thay thế khi test.

## 10. Nguồn API

- [UIWindowScene](https://developer.apple.com/documentation/uikit/uiwindowscene)
- [UIWindow](https://developer.apple.com/documentation/uikit/uiwindow)
- [UITabBarController](https://developer.apple.com/documentation/uikit/uitabbarcontroller)
- [UINavigationController](https://developer.apple.com/documentation/uikit/uinavigationcontroller)
- [UISplitViewController](https://developer.apple.com/documentation/uikit/uisplitviewcontroller)
- [UISplitViewControllerDelegate](https://developer.apple.com/documentation/uikit/uisplitviewcontrollerdelegate)
- [Custom container](https://developer.apple.com/documentation/uikit/creating-a-custom-container-view-controller)

Các chính sách route, class ứng dụng, vòng đời coordinator và composition trong tài liệu là đề xuất thiết kế cho sản phẩm; nguồn Apple chỉ xác nhận vai trò và khả năng API.
