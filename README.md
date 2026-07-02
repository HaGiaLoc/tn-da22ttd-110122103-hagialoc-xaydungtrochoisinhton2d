# Sinh Tồn 2D

**Tên đề tài -** Xây dựng trò chơi sinh tồn 2D với cơ chế thu thập tài nguyên và chiến đấu góc nhìn từ trên xuống.


|                          |               |
| ------------------------ | ------------- |
| **Giảng viên hướng dẫn** | Khấu Văn Nhựt |
| **Sinh viên thực hiện**  | Hà Gia Lộc    |
| **MSSV**                 | 110122103     |
| **Lớp**                  | DA22TTD       |
| **Khóa**                 | 2022          |


---

## 1. Giới thiệu

**Sinh Tồn 2D** là trò chơi sinh tồn 2D góc nhìn từ trên xuống (top-down), được xây dựng bằng **Godot Engine 4.7** và **GDScript**. Người chơi bị mắc kẹt trên một hòn đảo, cần thu thập tài nguyên, chế tạo công cụ, xây dựng cơ sở, chiến đấu với kẻ thù, duy trì chỉ số sinh tồn (máu, đói) và cuối cùng kích hoạt Cổng dịch chuyển để thoát khỏi đảo.

Dự án triển khai các hệ thống cốt lõi của game sinh tồn: túi đồ & trang bị, chế tạo & xây dựng, AI kẻ thù/động vật, lưu/tải game, tutorial hướng dẫn và quản lý âm thanh theo ngữ cảnh.

---



## 2. Mục tiêu



### 2.1. Mục tiêu chung

- Xây dựng trò chơi sinh tồn 2D hoàn chỉnh có thể chạy được trên máy tính cá nhân.
- Ứng dụng kiến thức lập trình game: scene graph, vật lý 2D, AI, quản lý trạng thái và lưu trữ dữ liệu.
- Đáp ứng yêu cầu đồ án tốt nghiệp về phân tích, thiết kế, cài đặt và đánh giá sản phẩm phần mềm.



### 2.2. Mục tiêu cụ thể


| STT | Mục tiêu                              | Kết quả đạt được                                               |
| --- | ------------------------------------- | -------------------------------------------------------------- |
| 1   | Thiết kế gameplay sinh tồn top-down   | Di chuyển 8 hướng, hệ thống máu/đói, camera theo người chơi    |
| 2   | Xây dựng hệ thống thu thập tài nguyên | Khai thác cây, bụi, đá, quặng; spawner tái sinh tài nguyên     |
| 3   | Xây dựng hệ thống túi đồ & trang bị   | Túi đồ, hotbar, kho, trang bị, affix, tooltip                  |
| 4   | Xây dựng hệ thống chế tạo & xây dựng  | Chế tạo cơ bản, bàn chế tạo, lò nung, đe, đặt công trình       |
| 5   | Xây dựng hệ thống chiến đấu           | HitBox/HurtBox, combo cận chiến, vũ khí & giáp                 |
| 6   | Xây dựng AI kẻ thù & động vật         | Sói (tuần tra, đuổi, tấn công); hươu (tuần tra, chạy trốn)     |
| 7   | Xây dựng hệ thống lưu/tải game        | Lưu vị trí, inventory, công trình, entity, tutorial            |
| 8   | Hoàn thiện luồng chơi & kết thúc      | Tutorial từng bước, màn thua/thắng, kích hoạt Cổng dịch chuyển |


---



## 3. Kiến trúc



### 3.1. Cấu trúc thư mục

```
.
├── README.md
├── src/                          # Dự án Godot
│   ├── project.godot             # Cấu hình engine & autoload
│   ├── scenes/                   # Scene game (.tscn)
│   ├── scripts/                  # Mã nguồn GDScript
│   │   ├── Player/               # Người chơi, camera, hit/hurt box
│   │   ├── Enemy/                # AI sói
│   │   ├── Animal/               # AI hươu
│   │   ├── Building/             # Công trình tương tác
│   │   ├── InventorySystem/      # Túi đồ, chế tạo, trang bị
│   │   ├── Resource/             # Node tài nguyên & spawner
│   │   └── Global/               # Tutorial, âm nhạc, tương tác
│   ├── resources/                # Item, recipe, loot table (.tres)
│   └── assets/                   # Sprite, nhạc, hiệu ứng
└── thesis/                       # Báo cáo đồ án (doc, pdf)
```



### 3.2. Các module chính


| Module          | Thư mục / Scene                      | Chức năng                                  |
| --------------- | ------------------------------------ | ------------------------------------------ |
| **Core**        | `game.gd`, `main_menu.gd`            | Luồng game, menu, pause, chuyển scene      |
| **Player**      | `scripts/Player/`                    | Di chuyển, đói/máu, tấn công, trang bị     |
| **Inventory**   | `scripts/InventorySystem/`           | Túi đồ, hotbar, chế tạo, tooltip, affix    |
| **Resource**    | `scripts/Resource/`                  | Node tài nguyên, spawner tái sinh          |
| **Building**    | `scripts/Building/`                  | Bàn chế tạo, lò, đe, rương, cổng           |
| **Combat**      | `Player/`, `Enemy/`, `Animal/`       | HitBox, HurtBox, sát thương, loot          |
| **AI**          | `Enemy/enemy.gd`, `Animal/animal.gd` | Tuần tra, phát hiện, đuổi/tấn công/bỏ chạy |
| **Persistence** | `SaveSystem.gd`                      | Serialize/deserialize trạng thái game      |
| **Tutorial**    | `Global/TutorialManager.gd`          | Nhiệm vụ hướng dẫn từng bước               |




### 3.3. Autoload (Singleton)


| Tên                  | Vai trò                                              |
| -------------------- | ---------------------------------------------------- |
| `InventorySystem`    | Quản lý toàn bộ inventory, vật phẩm, chế tạo         |
| `SaveSystem`         | Lưu / tải game                                       |
| `TutorialManager`    | Theo dõi tiến trình tutorial                         |
| `MusicManager`       | Nhạc nền theo trạng thái (menu, khám phá, chiến đấu) |
| `InteractionManager` | Ưu tiên đối tượng tương tác khi có nhiều target      |
| `WaterTileChecker`   | Kiểm tra tile nước trên bản đồ                       |
| `ItemTooltip`        | Hiển thị tooltip vật phẩm                            |




## 4. Phần mềm cần thiết để triển khai



### 4.1. Phần mềm bắt buộc


| Phần mềm                                         | Phiên bản                       | Mục đích                       |
| ------------------------------------------------ | ------------------------------- | ------------------------------ |
| [Godot Engine](https://godotengine.org/download) | **4.7**                         | Engine phát triển và chạy game |
| Git                                              | Mới nhất                        | Clone mã nguồn từ repository   |
| Hệ điều hành                                     | Windows 10/11, Linux hoặc macOS | Môi trường chạy Godot & game   |


> **Lưu ý:** Dự án dùng Godot 4.7. Không tương thích với Godot 3.x.



### 4.2. Yêu cầu phần cứng (khuyến nghị)


| Thành phần       | Yêu cầu                                          |
| ---------------- | ------------------------------------------------ |
| CPU              | Intel Core i3 trở lên (hoặc tương đương)         |
| RAM              | 4 GB trở lên                                     |
| GPU              | Hỗ trợ DirectX 12 (Windows) hoặc Vulkan / OpenGL |
| Dung lượng ổ đĩa | ~500 MB (mã nguồn + Godot + bản build)           |




### 4.3. Công nghệ sử dụng


| Thành phần         | Chi tiết                                 |
| ------------------ | ---------------------------------------- |
| Engine             | Godot 4.7                                |
| Ngôn ngữ           | GDScript                                 |
| Renderer (Windows) | DirectX 12                               |
| Định dạng dữ liệu  | `.tscn`, `.tres`, `.gd`                  |
| Lưu game           | Binary serialize (`user://savegame.sav`) |


---



## 5. Cách thức chạy chương trình



### 5.1. Chạy từ mã nguồn (Godot Editor)

**Bước 1 — Clone repository**

```bash
git clone https://github.com/HaGiaLoc/tn-da22ttd-110122103-hagialoc-xaydungtrochoisinhton2d.git
cd tn-da22ttd-110122103-hagialoc-xaydungtrochoisinhton2d
```

**Bước 2 — Mở dự án Godot**

1. Cài đặt và mở **Godot 4.7**.
2. Chọn **Import** → trỏ tới file `src/project.godot`.
3. Nhấn **Import & Edit** để mở project.

> Thư mục Godot project nằm trong `src/`. Không import thư mục gốc repository.

**Bước 3 — Chạy game**

- Nhấn **F5** hoặc nút **Play (▶)** trên Godot Editor.
- Scene khởi động: `main_menu.tscn`.



### 5.2. Export bản build từ Godot (tùy chọn)

1. Cài **Export Templates** cho Godot 4.7: *Editor → Manage Export Templates*.
2. Mở project → *Project → Export…* → thêm preset **Windows Desktop**.
3. Chọn thư mục output → **Export Project**.



### 5.3. Hướng dẫn chơi nhanh


| Phím            | Chức năng     |
| --------------- | ------------- |
| `W` `A` `S` `D` | Di chuyển     |
| `Shift`         | Chạy          |
| Chuột trái      | Tấn công      |
| `F`             | Tương tác     |
| `I`             | Mở túi đồ     |
| `E`             | Dùng vật phẩm |
| `1`–`6`         | Chọn hotbar   |
| `Esc`           | Tạm dừng      |


**Menu chính:** *Chơi mới* (xóa save cũ) · *Tiếp tục* (tải save) · *Cài đặt* · *Thoát*

**Điều kiện thắng:** Thu thập nguyên liệu và kích hoạt Cổng dịch chuyển (10 Kim cương, 99 Đồng vàng, 10 Ngọc lục bảo, 10 Nanh sói).