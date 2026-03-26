---
name: update-category
description: Quản lý danh mục (CRUD) tinh gọn với Tab hiển thị tổng chi tiêu và ToastService dùng chung.
status: backlog
priority: P1
scale: medium
created: 2026-03-26T16:15:00Z
updated: null
---

# PRD: update-category

## Executive Summary
Tính năng này cho phép người dùng tự do quản lý (thêm, sửa, xóa) các danh mục chi tiêu của mình thay vì bị bó buộc trong 7 danh mục mặc định. Chúng ta sẽ bổ sung một Tab "Categories" mới để hiển thị danh sách và tổng chi tiêu theo từng hạng mục. Đi kèm với đó là một `ToastService` chuyên biệt để chuẩn hóa việc thông báo trạng thái hệ thống. Mục tiêu là giúp người dùng cá nhân hóa cấu trúc tài chính mà không làm mất an toàn dữ liệu.

## Problem Statement
Hiện tại, người dùng không thể thay đổi hoặc thêm mới danh mục, dẫn đến việc phải ép các giao dịch đặc thù (như "Thú cưng", "Học tập") vào các nhóm chung chung, làm giảm độ chính xác của báo cáo tài chính. Ngoài ra, việc xóa danh mục nếu không được xử lý cẩn thận có thể dẫn đến mất mát dữ liệu hoặc tạo ra các giao dịch "mồ côi". Hệ thống cũng đang thiếu một cơ chế thông báo (Toast) đồng nhất cho các thao tác thành công hoặc thất bại.

## Target Users
- **Người dùng có thói quen chi tiêu đặc thù (Persona: Specialist):** Những người cần các danh mục chuyên biệt (freelancer, sinh viên, người có sở thích tốn kém) để theo dõi dòng tiền chính xác. (Pain level: High)
- **Người dùng yêu thích sự ngăn nắp (Persona: Organizer):** Muốn đổi tên các danh mục mặc định theo ngôn ngữ cá nhân để cảm thấy kiểm soát ví tiền tốt hơn. (Pain level: Medium)

## User Stories
**US-1: Tạo danh mục mới**
As a Specialist user, I want to add a new category with a custom name so that I can track my unique expenses.
Acceptance Criteria:
- [ ] Nút "Thêm" nằm ở đầu danh sách, ngang hàng với tiêu đề.
- [ ] Kiểm tra trùng tên ngay khi người dùng đang nhập liệu.
- [ ] Thông báo thành công qua ToastService sau khi lưu vào DB.

**US-2: Xóa danh mục an toàn**
As an Organizer user, I want to delete an unnecessary category without losing my transaction history.
Acceptance Criteria:
- [ ] Hiển thị hộp thoại xác nhận kèm số lượng record bị ảnh hưởng.
- [ ] Sau khi xác nhận, toàn bộ record thuộc danh mục bị xóa tự động chuyển về "Uncategorized" (ID 1).
- [ ] Danh mục "Uncategorized" không thể bị xóa hoặc sửa tên.

**US-3: Xem tổng quan chi tiêu**
As a user, I want to see a list of my categories and their total spent amounts in a dedicated tab.
Acceptance Criteria:
- [ ] Hiển thị dạng List view đơn giản.
- [ ] Mỗi dòng hiển thị tên danh mục và tổng số tiền tích lũy từ các giao dịch liên quan.

## Requirements

### Functional Requirements (MUST)

**FR-1: Quản lý Category trong Database & Provider**
Thực hiện các phương thức CRUD (Create, Read, Update, Delete) trong `RecordRepository` và đồng bộ cache trong `RecordProvider`.
Scenario: Xóa danh mục
- GIVEN Danh mục "Cà phê" có 15 giao dịch.
- WHEN Người dùng chọn xóa danh mục "Cà phê".
- THEN Hiển thị cảnh báo "15 giao dịch sẽ được chuyển về Uncategorized. Tiếp tục?".
- AND Nếu đồng ý, danh mục bị xóa khỏi DB và 15 giao dịch được cập nhật `category_id = 1` trong cùng một transaction.

**FR-2: Tab Categories (Giao diện List)**
Bổ sung Tab thứ 3 vào BottomNavigationBar.
Scenario: Hiển thị danh sách
- GIVEN Người dùng chuyển sang Tab Categories.
- THEN Hệ thống hiển thị danh sách dạng List, sắp xếp theo thứ tự bảng chữ cái (trừ Uncategorized luôn ở đầu).
- AND Mỗi dòng hiển thị tên và tổng tiền (Amount).

**FR-3: Kiểm tra trùng lặp (Duplicate Check)**
Scenario: Nhập tên trùng
- GIVEN Đã có danh mục tên "Ăn uống".
- WHEN Người dùng nhập "Ăn uống" vào ô tên khi thêm mới.
- THEN Hiển thị lỗi đỏ ngay bên dưới ô nhập: "Tên danh mục đã tồn tại".

**FR-4: ToastService chuyên biệt**
Xây dựng một service singleton để hiển thị thông báo.
Scenario: Thông báo trạng thái
- GIVEN Một thao tác lưu dữ liệu vừa hoàn thành.
- WHEN `ToastService.showSuccess('Đã lưu thành công')` được gọi.
- THEN Hiển thị một Snackbar/Toast với style xanh lá, tự biến mất sau 2-3 giây.
- AND Hỗ trợ các mode: Success (Xanh), Failure (Đỏ), Static Warning (Vàng/Cam).

### Functional Requirements (NICE-TO-HAVE)
**NTH-1: Search Category**
Tìm kiếm danh mục theo tên trong Tab Categories khi danh sách trở nên dài.

### Non-Functional Requirements
**NFR-1: Data Integrity**
Tất cả các thao tác xóa danh mục và chuyển đổi giao dịch phải nằm trong một atomic transaction (SQLite).
**NFR-2: Performance**
Thời gian load danh sách Category và tính toán tổng tiền phải < 150ms cho tối đa 100 danh mục.

## Success Criteria
- [ ] 100% các giao dịch của danh mục bị xóa được chuyển về Uncategorized thành công.
- [ ] Người dùng có thể thêm danh mục mới và sử dụng ngay lập tức trong màn hình Chat (thông qua Provider).
- [ ] ToastService được áp dụng đồng nhất cho ít nhất 3 hành động: Thêm, Sửa, Xóa.

## Risks & Mitigations
| Risk | Severity | Likelihood | Mitigation |
| :--- | :--- | :--- | :--- |
| Xung đột ID khi xóa danh mục mặc định | High | Low | Hardcode quy tắc không cho phép sửa/xóa ID 1 trong cả UI và Repository. |
| UI bị giật khi tính toán tổng tiền lớn | Medium | Medium | Sử dụng `FutureProvider` hoặc tính toán tổng tiền bằng SQL `SUM()` trực tiếp trong Repository thay vì tính tay trên List. |
| Người dùng lỡ tay xóa | Medium | Medium | Luôn yêu cầu xác nhận kèm số liệu cụ thể trước khi thực hiện xóa. |

## Constraints & Assumptions
- **Constraints:** ID 1 là "Uncategorized" và không thể thay đổi.
- **Assumptions:** Người dùng không cần Icon/Màu sắc để phân biệt danh mục trong giai đoạn này. Tên text là đủ.

## Out of Scope
- Chọn Icon hoặc Màu sắc cho Category.
- AI tự động gợi ý danh mục mới (để giai đoạn sau).
- Sắp xếp thứ tự danh mục thủ công (Drag & Drop).

## Dependencies
- **RecordRepository**: Cần cập nhật schema (nếu cần) và thêm logic transaction.
- **RecordProvider**: Cần listener để cập nhật dữ liệu khi Category thay đổi.

## _Metadata
<!-- Auto-generated. Updated by prd-edit. Read by prd-parse, prd-validate. -->
requirement_ids:
  must: [FR-1, FR-2, FR-3, FR-4]
  nice_to_have: [NTH-1]
  nfr: [NFR-1, NFR-2]
scale: medium
discovery_mode: express
validation_status: passed
last_validated: 2026-03-26T16:20:00Z
