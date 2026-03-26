---
name: update-category
status: backlog
created: 2026-03-26T16:25:00Z
progress: 0%
priority: P1
prd: .claude/prds/update-category.md
task_count: 5
github: "https://github.com/dainn67/wallet-ai/issues/121"
---

# Epic: update-category

## Overview
Epic này triển khai hệ thống quản lý danh mục (CRUD) toàn diện và Tab Categories để theo dõi chi tiêu. Chúng ta sẽ sử dụng pattern Singleton cho `ToastService` để đồng bộ thông báo trạng thái. Về mặt dữ liệu, chúng ta thực hiện các giao dịch SQLite nguyên tử (atomic transactions) để đảm bảo khi một danh mục bị xóa, toàn bộ bản ghi liên quan sẽ được chuyển về danh mục "Uncategorized" (ID 1) một cách an toàn. Tab Categories sẽ được tích hợp vào `HomeScreen` hiện tại, mở rộng từ 2 tab lên 3 tab (hoặc 4 nếu ở dev mode).

## Architecture Decisions

### AD-1: ToastService Singleton with Global Key
**Context:** Cần một cách tiếp cận đồng nhất để hiển thị thông báo (Success, Error, Warning) từ bất kỳ đâu (Service, Provider, UI) mà không cần truyền `BuildContext` liên tục.
**Decision:** Xây dựng `ToastService` sử dụng `GlobalKey<ScaffoldMessengerState>`. Đăng ký key này trong `MaterialApp` tại `main.dart`.
**Alternatives rejected:** Sử dụng `ScaffoldMessenger.of(context)` trực tiếp (yêu cầu context, gây khó khăn khi gọi từ Provider/Service).
**Trade-off:** Dễ dàng sử dụng toàn cục, nhưng phụ thuộc vào việc GlobalKey được gắn đúng vào `MaterialApp`.
**Reversibility:** Dễ dàng thay thế bằng các package như `fluttertoast` hoặc `overlay_support` nếu cần UI phức tạp hơn.

### AD-2: Atomic Category Deletion
**Context:** Xóa một danh mục yêu cầu cập nhật hàng loạt các bản ghi (Records) để tránh dữ liệu mồ côi.
**Decision:** Sử dụng `db.transaction()` trong `RecordRepository` để thực hiện đồng thời việc cập nhật `category_id` của các Records liên quan và xóa bản ghi Category.
**Alternatives rejected:** Cập nhật từng record một (chậm, rủi ro mất an toàn dữ liệu nếu lỗi giữa chừng).
**Trade-off:** Đảm bảo tính toàn vẹn dữ liệu tuyệt đối nhưng yêu cầu logic transaction cẩn thận.
**Reversibility:** Hard (Logic DB là core của tính năng).

## Technical Approach

### Toast Service
- **File:** `lib/services/toast_service.dart`
- **Pattern:** Singleton với `GlobalKey<ScaffoldMessengerState>`.
- **Methods:** `showSuccess(String message)`, `showError(String message)`, `showWarning(String message)`.
- **Integration:** Gắn key vào `MaterialApp.scaffoldMessengerKey` trong `lib/main.dart`.

### Data Layer (Repository & Provider)
- **RecordRepository (`lib/repositories/record_repository.dart`):**
    - Thêm `createCategory(Category category)`
    - Thêm `updateCategory(Category category)`
    - Thêm `deleteCategory(int id)` (kèm transaction chuyển records về ID 1).
    - Thêm `getRecordCountByCategoryId(int id)` để phục vụ việc hiển thị số lượng giao dịch bị ảnh hưởng khi xóa.
    - Thêm `getCategoryTotals()` sử dụng SQL `SUM()` và `GROUP BY` để lấy tổng chi tiêu theo danh mục.
- **RecordProvider (`lib/providers/record_provider.dart`):**
    - Thêm các method wrapper CRUD cho Category.
    - Cache kết quả tổng chi tiêu để UI hiển thị mượt mà.

### UI Layer (Tabs & Screens)
- **HomeScreen (`lib/screens/home/home_screen.dart`):**
    - Cập nhật `TabController` để hỗ trợ 3 tab chính: Chat, Records, Categories.
- **CategoriesTab (`lib/screens/home/tabs/categories_tab.dart`):**
    - List view hiển thị danh sách Categories.
    - Mỗi item hiển thị Tên và Tổng tiền (sử dụng `CurrencyHelper`).
    - Nút "Thêm" ở header (ngang hàng với Title).
    - Hộp thoại thêm/sửa danh mục có validation trùng tên.

## Traceability Matrix
| PRD Requirement | Epic Coverage | Task(s) | Verification |
| --------------- | ------------- | ------- | ------------ |
| FR-1: Quản lý Category | §Technical Approach / Data Layer | T1, T2 | Unit test repo + integration test provider |
| FR-2: Tab Categories | §Technical Approach / UI Layer | T3, T4 | Widget test + Manual test UI |
| FR-3: Kiểm tra trùng lặp | §Technical Approach / UI Layer | T4 | Manual test gõ tên trùng |
| FR-4: ToastService | §Technical Approach / Toast Service | T1 | Manual verify toast hiển thị đúng màu |
| NFR-1: Data Integrity | AD-2 & §Data Layer | T2 | Unit test DB transaction |
| NFR-2: Performance | §Data Layer (SQL SUM) | T2 | Manual verify với 100+ records |

## Implementation Strategy
### Phase 1: Foundation
Xây dựng `ToastService` và hoàn thiện logic CRUD trong Repository.
**Exit Criterion:** Có thể thêm/sửa/xóa Category trong DB và hiển thị Toast thành công/thất bại mà không lỗi.

### Phase 2: Core Features
Triển khai Tab Categories và tích hợp vào HomeScreen.
**Exit Criterion:** Tab Categories hiển thị đúng danh sách và tổng tiền; các nút CRUD hoạt động tốt từ UI.

### Phase 3: Polish
Hoàn thiện validation trùng tên, dialog xác nhận xóa kèm số lượng record, và xử lý các cạnh (ID 1).
**Exit Criterion:** Không thể xóa ID 1; UI hiển thị lỗi khi tên trùng.

## Task Breakdown

## Tasks Created
| #   | Task                     | Phase | Parallel | Est. | Depends On | Status |
| --- | ------------------------ | ----- | -------- | ---- | ---------- | ------ |
| 001 | ToastService Integration | 1     | no       | 0.5d | —          | open   |
| 002 | Repo & Provider CRUD     | 1     | yes      | 1d   | 001        | open   |
| 010 | CategoriesTab Scaffold   | 2     | yes      | 0.5d | 001        | open   |
| 011 | Category Management UI   | 2     | yes      | 1d   | 002, 010   | open   |
| 020 | ID 1 Protection          | 3     | yes      | 0.5d | 011        | open   |
| 090 | Integration verification | 3     | no       | 0.5d | all        | open   |

### Summary
- **Total tasks:** 6
- **Parallel tasks:** 4 (Phase 1, 2, 3)
- **Sequential tasks:** 2 (Initial setup + Final verification)
- **Estimated total effort:** 4 days
- **Critical path:** T001 → T002 → T011 → T020 → T090 (~3 days)

### Dependency Graph
```
  T001 ──→ T002 ──→ T011 ──→ T020 ──→ T090
       ──→ T010 ──→ T011
```

### PRD Coverage
| PRD Requirement | Covered By | Status    |
| --------------- | ---------- | --------- |
| FR-1: Quản lý Category | T002, T011 | ✅ Covered |
| FR-2: Tab Categories | T010, T011 | ✅ Covered |
| FR-3: Kiểm tra trùng lặp | T011       | ✅ Covered |
| FR-4: ToastService | T001       | ✅ Covered |
| US-1: Tạo danh mục mới | T011       | ✅ Covered |
| US-2: Xóa danh mục an toàn | T002, T011, T020 | ✅ Covered |
| US-3: Xem tổng quan | T011       | ✅ Covered |
| NFR-1: Data Integrity | T002       | ✅ Covered |
| NFR-2: Performance | T002       | ✅ Covered |

## Risks & Mitigations
| Risk | Severity | Likelihood | Impact | Mitigation |
| ---- | -------- | ---------- | ------ | ---------- |
| Lỗi Transaction khi xóa Category | High | Low | Mất dữ liệu giao dịch | Sử dụng Unit Test bao phủ mọi trường hợp xóa (có record và không record). |
| Crash ToastService | Medium | Low | App crash khi thông báo | Khởi tạo GlobalKey sớm và kiểm tra null-safety. |
| Hiệu năng tính tổng tiền chậm | Medium | Medium | UI lag khi chuyển tab | Sử dụng SQL `SUM()` thay vì tính toán trên mảng Dart. |

## Dependencies
- **RecordRepository**: Cần sẵn sàng cho các thay đổi schema (nếu cần nâng cấp version DB).
- **Localization**: Cần bổ sung key cho Tab mới và các thông báo.

## Success Criteria (Technical)
| PRD Criterion | Technical Metric | Target | How to Measure |
| ------------- | ---------------- | ------ | -------------- |
| 100% records chuyển về ID 1 | Record count mismatch | 0 | Unit test sql query sau khi delete. |
| ToastService đồng nhất | Style consistency | 100% | Manual audit các màn hình dùng Toast. |
| Performance load < 150ms | Render frame delay | < 16ms | Flutter DevTools Performance overlay. |

## Estimated Effort
- **Total Estimate:** 3.5 days
- **Critical Path:** T1 -> T2 -> T4 -> T5
- **Phases Timeline:** 4 ngày làm việc (bao gồm test).

## Deferred / Follow-up
- **NTH-1: Search Category** - Tạm hoãn để ưu tiên tính ổn định của CRUD cơ bản.
- **Icons/Colors** - Sẽ triển khai khi có thiết kế UI chi tiết hơn cho danh mục.
