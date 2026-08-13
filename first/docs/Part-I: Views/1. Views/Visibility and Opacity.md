# Visibility and Opacity

- isHiden
- backgroundColor
- alpha
- isOpaque
thường bị gộp chung là làm mờ/ ẩn `view`, nhưng bản chất chúng vận hành ở 3 tầng khác nhau
> Tầng hiện diện, tương tác
> Tầng compositing hình ảnh theo cây cascade
> Tầng gợi ý hiệu năng `render`

# Mục tiêu
- Phân biệt rõ `isHiden` với removeFromSuperview() về chi phí và khả năng thao tác
- Hiểu `alpha` cascade theo cơ chế nhân dồn qua nhiều cấp parrent-child, không phải gán độc lập từng `view`
- `isOpaque` - property duy nhất trong nhóm này không tự động đồng bộ theo `alpha/backgroundColor`  -> gây artifact khi tự custom `draw(_:)`

## 1. isHidden - loại khỏi interface mà không loại khỏi view hierarchy

`isHidden = true` khác `removeFromSuperView()` ở 2 điểm
- Không tốn chi phí rebuild hierarchy, và không mất vị trí index trong `subviews`
> Khôi phục chỉ cần set `false`, không cần `insertSubview(at:)` 
> `View` vẫn tồn tại trong cây, vẫn thao tác được bằng code, chỉ không nhận touch theo cách thông thường

## 2. `backgroundColor = nil` - container thuần tuý, không tự vẽ

View với `backgroundColor = nil` hợp lệ chỉ đóng vai trò đơn vị tổ chức trong cây, không tự vẽ gì - dùng để gom nhóm subview để thực hiện hành động đồng loạt ( di chuyển, ẩn, animate cùng lúc)

## 3. `alpha` 

- `subview` không thể vượt chỉ số `alpha` đang set của superview

- `UIColor` có alpha component độc lập với `UIView.alpha`

``` swift
view.alpha = 1
view.backgroundColor = UIColor.red.withAlphaComponent(0.3) // View không trong suốt theo alpha, nhưng nền vẫn hiện xuyên quan do color - alpha có giá trị khác
```

## 4. isOpaqua - hint hiệu năng, không ảnh hưởng tới appearance

Thay đổi giá trị này không có ảnh hưởng gì tới hình thức hiển thị `appearance` của `view`. Thay vào đó, đây là một gợi ý cho hệ thống vẽ `drawing system`

> Nếu một `view` được lấp đầy hoàn toàn bằng `bounds` của nó bằng vật liệu `opaque` và có `alpha = 1.0` - tức lag không có độ trong suốt nào thì nó sẽ được vẽ hiệu quả hơn (ít ảnh hưởng tới hiệu năng) nếu bạn báo cho hệ thống vẽ biết bằng cách set `isOpaque = true`. Ngược lại nên set `isOpaque = false`

Giá trị `isOpaque` không tự động thay đổi khi set `backgroundColor` hoặc `alpha` của `view`. Việc set đúng giá trị này là trách nhiệm của engineer.
