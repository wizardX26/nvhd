# The Window

Nội dung này xây dựng mental model về cách UIKit hiển thị và quản lý interface từ lúc app khởi động.

## Mục tiêu

Sau chương này, engineer có thể:

- Giải thích vai trò của `UIView`, view hierarchy và `UIWindow`.
- Phân biệt trách nhiệm của `AppDelegate` và `SceneDelegate`.
- Khởi tạo interface bằng code mà không dùng storyboard.
- Tham chiếu đúng window trong app hỗ trợ nhiều scene.

## 1. UIView không chỉ dùng để vẽ

`UIView` có hai vai trò:

- Vẽ nội dung trong một vùng hình chữ nhật.
- Nhận và xử lý sự kiện vì `UIView` kế thừa `UIResponder`.

Engineer có thể cấu hình view một lần bằng Interface Builder hoặc thay đổi view tại runtime bằng code, chẳng hạn như animation, resize và di chuyển.

> View hierarchy là cây render. Nó có liên hệ chặt với responder chain nhưng hai cấu trúc này không hoàn toàn giống nhau.

## 2. View hierarchy

Mỗi subview có một superview. Thay đổi trên superview sẽ lan xuống các subview:

- Xóa superview thì các subview cũng bị loại khỏi hierarchy.
- Ẩn superview thì các subview cũng bị ẩn.
- Di chuyển superview thì các subview di chuyển theo.

Engineer cũng có thể gắn gesture recognizer vào một view để nhận tương tác trong khu vực của view đó.

## 3. UIWindow và scene-based lifecycle

`UIWindow` là container cấp cao chứa view hierarchy và chuyển sự kiện đến các view. Trong scene-based lifecycle, mỗi window thuộc về một `UIWindowScene`.

```text
UIApplication
└── UISceneSession
    └── UIWindowScene
        └── UIWindow
            └── UIViewController
                └── UIView hierarchy
```

### Trước iOS 13.0: AppDelegate lifecycle

`AppDelegate` quản lý app lifecycle và giữ main window với các bước setup

1. UIKit tạo `UIApplication` và `AppDelegate`.
2. UIKit đọc `UIMainStoryboardFile` nếu app dùng main storyboard.
3. UIKit tạo `UIWindow` và initial view controller.
4. UIKit gọi `application(_:didFinishLaunchingWithOptions:)`.
5. Window được hiển thị bằng `makeKeyAndVisible()`.

### Sau iOS 13.0: Scene-based lifecycle

Scene-based lifecycle tách app process khỏi từng instance của interface:

- `AppDelegate` quản lý cấu hình và tài nguyên dùng chung cho toàn app.
- `SceneDelegate` quản lý lifecycle, window và interface của một scene.
- `UISceneSession` lưu thông tin định danh và cấu hình của scene.
- `UIWindowScene` chứa một hoặc nhiều window của scene.

Flow cơ bản:

1. UIKit tạo `UIApplication` và `AppDelegate`.
2. UIKit gọi `application(_:didFinishLaunchingWithOptions:)`.
3. UIKit đọc `UIApplicationSceneManifest`.
4. UIKit tạo hoặc khôi phục một `UISceneSession`.
5. UIKit tạo `UIWindowScene` và `SceneDelegate`.
6. UIKit gọi `scene(_:willConnectTo:options:)` để engineer cấu hình interface của scene.

Với file storyboard, UIKit có thể tạo window và initial view controller từ scene configuration. Nếu app không dùng storyboard, engineer khởi tạo và cấu hình thủ công trong `SceneDelegate`.

### Vai trò của AppDelegate

`AppDelegate` xử lý các công việc ở cấp app:

- Khởi tạo dependency và dữ liệu dùng chung.
- Đăng ký service như push notification.
- Cung cấp `UISceneConfiguration` cho scene mới.
- Dọn dữ liệu của các scene session đã bị hủy.

```swift
@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        UISceneConfiguration(
            name: "Default Configuration",
            sessionRole: connectingSceneSession.role
        )
    }
}
```

### Vai trò của SceneDelegate

`SceneDelegate` xử lý các công việc gắn với một instance của interface:

- Tạo và giữ `UIWindow`.
- Cấu hình root view controller.
- Xử lý trạng thái active, inactive, foreground và background của scene.

```swift
final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = ViewController()
        self.window = window
        window.makeKeyAndVisible()
    }
}
```

Engineer phải giữ strong reference đến window bằng `SceneDelegate.window (self.window)`. Nếu không, window có thể bị giải phóng sau khi `scene(_:willConnectTo:options:)` kết thúc.

### Yêu cầu từ iOS 27

Từ iOS 27, app build bằng SDK mới nhất phải dùng scene-based lifecycle. Ứng dụng không tích hợp sẽ không launch. Cấu hình cần có bao gồm:

- `Info.plist` có `UIApplicationSceneManifest` và scene configuration hợp lệ.
- `AppDelegate` triển khai `application(_:configurationForConnecting:options:)`.
- Lifecycle của interface được xử lý bằng `UISceneDelegate` hoặc `UIWindowSceneDelegate`.

Apple chỉ bắt buộc scene-based lifecycle, không bắt buộc phải hỗ trợ nhiều scene.

## 4. Tham chiếu tới window tại runtime

### Từ một view

Ưu tiên dùng window đã gắn với view:

```swift
let window = view.window
let windowScene = view.window?.windowScene
```

Nếu `view.window` là `nil`, view chưa nằm trong window hierarchy và chưa hiển thị trên màn hình.

### Từ một UIWindowScene

Khi engineer đã có scene context, có thể lấy key window của scene đó:

```swift
let keyWindow = windowScene.windows.first(where: \.isKeyWindow)
```

### Những cách không nên dùng

Không lấy window qua:

```swift
(UIApplication.shared.delegate as? AppDelegate)?.window
UIApplication.shared.keyWindow
```

`AppDelegate` không đại diện cho một scene cụ thể. `UIApplication.shared.keyWindow` đã deprecated vì có thể trả về window thuộc scene khác.

Engineer nên truyền `UIWindow` hoặc `UIWindowScene` từ context hiện tại thay vì tìm một window toàn cục.

## Phụ lục - A

### Bỏ Main.storyboard và dựng ViewController đầu tiên bằng code

1. Xóa file `Main.storyboard`.
2. Mở target, chọn **Info**. (Info.plist ở 2 nơi)
3. Đi tới **Application Scene Manifest > Scene Configuration > Application Session Role > Item 0**.
4. Xóa cặp key-value **Storyboard Name**.
5. Trong **Build Settings**, tìm **UIKit Main Storyboard File Base Name** và xóa giá trị `Main` nếu còn tồn tại.
7. Tạo `UIWindow` và root view controller trong `scene(_:willConnectTo:options:)` như ví dụ ở trên.

Nếu Xcode tự sinh `Info.plist`, engineer chỉnh scene configuration trong tab **Info** của target thay vì tìm một file `Info.plist`.

## Tài liệu tham khảo

- [Transitioning to the UIKit scene-based life cycle](https://developer.apple.com/documentation/uikit/transitioning-to-the-uikit-scene-based-life-cycle)
- [Managing your app's life cycle](https://developer.apple.com/documentation/uikit/managing-your-app-s-life-cycle)
- [Specifying the scenes your app supports](https://developer.apple.com/documentation/uikit/specifying-the-scenes-your-app-supports)
- [Creating a UIWindow with init(windowScene:)](https://developer.apple.com/documentation/uikit/uiwindow/init%28windowscene%3A%29)
