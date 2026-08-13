# Frame
Frame thể hiện bằng kiểu CGRect

## Mục tiêu

Hiểu vị trí, kích thước, quan hệ với các View khác

## 1. Hệ toạ độ

Trong UIKit, hệ toạ dộ hiển thị trong interface được biểu diễn
- Gốc (0,0)ở góc trên bên trái

```
(0,0)

|-------------------------- (x)
|
|
|
|
|
|
|
|
|
|
|
|
|
(y)

```

> y càng lớn thì view càng nằm thấp xuống màn hình.

## 2. Set `frame` để làm gì?

Phân tích 2 tình huống

- `View` đã hiển thị -> đổi `frame` là đổi vị trí/kích thước ngay lập tức, thay đổi này nhận thấy bằng mắt trên màn hình
- `View` chưa có `superview` -> `frame` ở thời điểm này nên hiểu: "Khi nào view được thêm vào `superview`, sẽ đứng ở vị trí đó"

## 3. `init(frame:)`

- Nếu engineer không tự set `frame`, default sẽ là `CGRect.zero` - `width` = 0, `height` = 0

## Phụ lục - A
"Tại sao tôi add subview rồi mà không thấy hiển thị?"
* `frame` đang bằng 0 (CGRect.zero) dù đã set `addSubview()` đúng cách

> `set` kích thước trước `khi addSubview`
> Nếu kích thước `view` được quyết định kích thước bằng nội dung của nó (ví dụ như `UIButton` cần kích thước vừa đủ để chứa `title`) -> gọi `sizeToFit` thay vì tự tính width/height.

## Phụ lục - B

``` swift

let v1 = UIView(frame: CGRect(23, 52, 100, 200))
v1.backgroundColor = ...

let v2 = UIView(frame: CGRect(0, 0, 50, 100))
v2.backgroundColor = ...

let v3 = UIView(frame: CGRect(0, 50, 50, 50)
v3.backgroundColor = ...

rootView.addSubview(v1)
v1.addSubview(v2)
rootView.addSubview(v3)
```

- v2 nằm trong v1, không phải nằm trong `rootView`: tức là frame của v2 khai báo ở trên được tính theo hệ toạ độ của v1, không phải của `rootView`
> `frame` là tương đối so với `superview`

- v1 và v3 là `child view` của `rootView`. Thứ tự `z-order` (trên, dưới) được quyết định bởi thứ tự `addSubview` của `superview` (hoặc `insertSubview()`)
> `z-order` không phải property lưu trữ riêng biệt, đơn giản là thứ tự trong mảng `subviews`