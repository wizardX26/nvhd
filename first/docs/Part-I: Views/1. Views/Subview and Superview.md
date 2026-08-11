# Subview and Superview

Đây là nội dung kiến trúc quan trọng nhất của chương - giải thích 1 bước ngoặt lịch sử làm thay đổi hoàn toàn cách hiểu về `view hierarchy`
> Từ đó suy ra các hệ quả thực tế và API thao tác

## Mục tiêu

- Hiểu về `view hierarchy`

## 1. Sở hữu vùng vẽ -> layering linh hoạt

Model cũ ( trước OS X 10.5): mỗi view sở hữu đúng vùng chữ nhật của nó theo nghĩa tuyệt đối, nghĩa là:

- Không phần nào của view khác (nếu không phải subview) được hiện bên trong view này, vì khi view này redraw, nó `erase` (xoá) phần chồng lấp của view khác.
- Không phần noà của subview được hiện bên ngoài superview - view chỉ chịu trách nhiệm đúng vùng của chính nó.

Kiến trúc mới mà iOS thừa hưởng phá vỡ 2 ràng buộc này:

- Subview có thể vẽ ra ngoài bounds của superview.
- 2 view có thể overlap, che nhau, vẽ trước/sau nhau và không cần có quan hệ subview/superview.

## Example practice

3 views chồng lên nhau

### Hệ quả cascade khác của hierarchy

Mở rộng danh sách "cascade" đã nêu ở phần Window, 4 hệ quả bổ sung thêm gồm: 

- Alpha (độ trong suốt) được kế thừa xuống subview - superview.alpha = 0.5 làm cho mọi subview bị mờ theo tỉ lệ đó
- `clipsToBounds` bật để cắt bỏ phần subview vẽ ra ngoài bounds của superview - là cách chủ động quay lại hành vi model cũ khi cần (với thiết kế mới, mặc định Apple cho phép vẽ tràn subview ra ngoài superview)
- Ownership kiểu mảng: superview retain các subview của nó, giống một array retain phần tử - subview bị release khi rời khỏi danh sách subviews (tức bị remove) hoặc khi superview chính nó biến mất.
> `removeFromSuperview()` sẽ giải phóng luôn view đó. Nếu định dùng lại view này, bắt buộc phải giữ một strong reference (thường qua property) trước khi remove - nếu không, view biến mất, không truy cập lại được
- resize tự động: nếu size của superview thay đổi, các subview cũng tự resize theo (AutoLayout/ autoresizing mask)


## Phụ lục - A

### API truy vấn và thao tác hierarchy

1. Truy vấn cấu trúc

``` swift

view.superview                      // UIView? — cha trực tiếp
view.subviews                       // [UIView] — theo thứ tự back-to-front
view.isDescendant(of: otherView)    // kiểm tra quan hệ ở BẤT KỲ độ sâu nào
view.viewWithTag(42)                // tìm theo tag, gửi từ 1 view cao hơn trong cây

```

2. Thêm/xoá

``` swift

superview.addSubview(v)             // v được add CUỐI danh sách → vẽ SAU CÙNG → hiện TRƯỚC NHẤT (frontmost)
v.removeFromSuperview()             // rời khỏi cây, và bị release

```

3. Sắp xếp thứ tự (vẽ z-order) trong code

``` swift

superview.insertSubview(v, at: 0)                       // chèn theo index cụ thể (0 = dưới cùng)
superview.insertSubview(v, belowSubview: otherView)     // chèn ngay dưới 1 view khác
superview.insertSubview(v, aboveSubview: otherView)     // chèn ngay trên 1 view khác
superview.exchangeSubview(at: 0, withSubviewAt: 2)      // đổi chỗ 2 sibling
superview.bringSubview(toFront: v)                      // đưa lên trước nhất
superview.sendSubview(toBack: v)                        // đưa xuống sau cùng

```

4. Xoá toàn bộ subview

UIKit không có method built-in để xóa tất cả subview cùng lúc. Nhưng vì subviews là bản copy immutable tại thời điểm truy cập (không phải live reference vào danh sách nội bộ), lặp và remove từng cái vẫn an toàn, không gặp lỗi "mutate collection while iterating":

``` swift

myView.subviews.forEach { $0.removeFromSuperview() }

```

5. 6 lifecycle callback phản ứng thay đổi hierarchy

callback cho phép subclass UIView để "nghe" các thay đổi cấu trúc — theo 3 cặp will/did:

``` swift

override func willRemoveSubview(_ subview: UIView)
override func didAddSubview(_ subview: UIView)

override func willMove(toSuperview newSuperview: UIView?)
override func didMoveToSuperview()

override func willMove(toWindow newWindow: UIWindow?)
override func didMoveToWindow()

```

## Phụ lục B - Nội dung bài thực hành

1. Tạo UIView bằng code

   - Khởi tạo bằng UIView(frame:).
   - Đặt backgroundColor.
   - Thêm vào root view bằng addSubview.
   - Quan sát sự khác nhau giữa frame của view và hệ tọa độ của superview.

2. Subview và superview

   - Một container đóng vai trò superview.
   - Ba view màu đỏ, xanh, vàng chồng lên nhau.
   - Một view vượt ra ngoài bounds của container.
   - Quan sát superview, subviews và thứ tự back-to-front.

3. Tương tác trực tiếp với hierarchy

   Màn hình sẽ có các nút điều khiển:

   - Bật/tắt clipsToBounds.
   - Thay đổi alpha của superview. (để sau)
   - Đưa một view lên trước hoặc xuống sau.
   - Xóa và thêm lại một view.
   - Resize container để quan sát Auto Layout/autoresizing.
   - Hiển thị kết quả của isDescendant(of:) và viewWithTag(_:).

4. Quan sát lifecycle

   Tạo một subclass nhỏ của UIView để in log:

   - didAddSubview
   - willRemoveSubview
   - willMove(toSuperview:)
   - didMoveToSuperview
   - willMove(toWindow:)
   - didMoveToWindow

## Định hướng giao diện

Màn hình thực hành gồm hai vùng chính:

``` text
ViewController.rootView
├── containerView
│   ├── redView      (tag: 101)
│   ├── blueView     (tag: 102)
│   └── greenView    (tag: 103)
└── configurationView
```

Ba color view là sibling trực tiếp của `containerView`. Frame của chúng được đặt lệch nhau để tạo vùng overlap, nhờ đó có thể quan sát thay đổi z-order.

Phần bố cục màn hình bên ngoài dùng Auto Layout để chạy tốt trên nhiều kích thước iPhone/iPad. Riêng ba view minh họa sẽ dùng frame có chủ đích để người học nhìn rõ hệ tọa độ, overlap và z-order.
