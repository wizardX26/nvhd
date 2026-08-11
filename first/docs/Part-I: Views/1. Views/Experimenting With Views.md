# Experimenting With Views

Nội dung này chuyển từ lý thuyết trừu tượng window, launch sequence ( UIApplicationMain -> UIWindow -> rootViewController -> root view)

## Mục tiêu

Sau chương này, engineer có thể:

- Hiểu View

## 1. Thực hành

- Chưa cần hiểu ViewController là gì.
- Thêm 1 view vào `interface` bằng code

Engineer chọn môi trường thử nghiệm đơn giản: 1 `storyboard`, 1 `scene`, 1 `view controller`
> Chính ViewController này sẽ tự động trở thành `rootViewController` của window khi app chạy

``` swift
override func viewDidLoad() {
    super.viewDidLoad()

    let mainView = self.view!
    let v = UIView(frame: CGRect(31, 03, 20, 24))
    v.backgroundColor = #colorLiteral(red: r, green: g, blue: b, alpha: a) // Color Literal (Xcode 8+)

    mainView.addSubview(v)
}
```



