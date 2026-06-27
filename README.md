# 🎮 Sinh Tồn 2D

Trò chơi sinh tồn 2D góc nhìn từ trên xuống — thu thập tài nguyên, chế tạo, chiến đấu và thoát khỏi hòn đảo.


|               |                                       |
| ------------- | ------------------------------------- |
| **Sinh viên** | Hà Gia Lộc                            |
| **MSSV**      | 110122103                             |
| **Lớp**       | DA22TTD                               |
| **Engine**    | [Godot 4.7](https://godotengine.org/) |
| **Ngôn ngữ**  | GDScript                              |


---

## 📖 Mô tả dự án

**Sinh Tồn 2D** là đồ án tốt nghiệp xây dựng trò chơi sinh tồn 2D với cơ chế thu thập tài nguyên và chiến đấu góc nhìn từ trên xuống (top-down). Người chơi bị mắc kẹt trên một hòn đảo, phải thu thập tài nguyên, chế tạo công cụ và trang bị, xây dựng cơ sở, chiến đấu với kẻ thù và sinh tồn trước cơ chế đói — cuối cùng sửa chữa và kích hoạt Cổng dịch chuyển để thoát khỏi đảo.

Trò chơi có hệ thống hướng dẫn từng bước (tutorial) giúp người chơi làm quen với các cơ chế cốt lõi.

---

## ✨ Tính năng chính

- 🍖 Sinh tồn với hệ thống máu và đói.
- ⛏️ Thu thập tài nguyên từ cây cối, đá và quặng.
- 🎒 Túi đồ, hotbar 6 ô, kho chứa và hệ thống trang bị có affix.
- 🔨 Chế tạo vật phẩm, xây dựng công trình và lưu trữ tài nguyên.
- ⚔️ Chiến đấu cận chiến với combo, HitBox và HurtBox riêng biệt.
- 🐺 AI động vật và kẻ thù với hành vi tuần tra, truy đuổi, tấn công hoặc bỏ chạy.
- 🌀 Hoàn thành tutorial và kích hoạt Cổng dịch chuyển để chiến thắng.
- 💾 Tự động lưu và tải toàn bộ tiến trình chơi.
- 🎵 Âm thanh động thay đổi theo từng ngữ cảnh trong game.
- 📷 Camera từ trên xuống với nhiều chế độ quan sát linh hoạt.

---

## 🚀 Hướng dẫn cài đặt

### ⚙️ Yêu cầu hệ thống

- **Godot Engine 4.7** trở lên — [tải tại godotengine.org](https://godotengine.org/download)
- Hệ điều hành: Windows / Linux / macOS

### 🔧 Chạy từ mã nguồn (Godot Editor)

```bash
# 1. Clone repository
git clone https://github.com/HaGiaLoc/tn-da22ttd-110122103-hagialoc-xaydungtrochoisinhton2d.git
cd tn-da22ttd-110122103-hagialoc-xaydungtrochoisinhton2d

# 2. Mở Godot 4.7 → Import → chọn file src/project.godot

# 3. Nhấn F5 (hoặc nút Play) để chạy game
```

> Thư mục dự án Godot nằm trong `src/`. Không mở thư mục gốc repository làm project root.

---

## 📚 Cách sử dụng

### Menu chính


| Nút          | Chức năng                                |
| ------------ | ---------------------------------------- |
| **Chơi mới** | Bắt đầu game mới (xóa bản lưu cũ nếu có) |
| **Tiếp tục** | Tải bản lưu gần nhất                     |
| **Cài đặt**  | Điều chỉnh âm lượng                      |
| **Thoát**    | Thoát game                               |


### Điều khiển


| Phím / Chuột    | Hành động                                  |
| --------------- | ------------------------------------------ |
| `W` `A` `S` `D` | Di chuyển                                  |
| `Shift`         | Chạy                                       |
| `C`             | Ngồi / cúi                                 |
| Chuột trái      | Tấn công                                   |
| `F`             | Tương tác (nhặt, mở rương, sửa cổng, v.v.) |
| `I`             | Mở / đóng túi đồ                           |
| `E`             | Sử dụng vật phẩm                           |
| `1` – `6`       | Chọn ô thanh nóng                          |
| `X`             | Thoát chế độ phá hủy công trình            |
| `Esc`           | Tạm dừng                                   |


### Mục tiêu chiến thắng

Thu thập đủ nguyên liệu và kích hoạt **Cổng dịch chuyển**:

- 10 Kim cương
- 99 Đồng vàng
- 10 Ngọc lục bảo
- 10 Nanh sói

---

## 🛠️ Công nghệ & phụ thuộc chính


| Thành phần         | Phiên bản / Mô tả        |
| ------------------ | ------------------------ |
| Godot Engine       | 4.7                      |
| Ngôn ngữ lập trình | GDScript                 |
| Renderer (Windows) | DirectX 12               |
| Physics Engine     | Jolt Physics (3D config) |


### Autoload (singleton)


| Tên                  | Vai trò                                        |
| -------------------- | ---------------------------------------------- |
| `InventorySystem`    | Quản lý toàn bộ túi đồ, vật phẩm, chế tạo      |
| `SaveSystem`         | Lưu / tải trạng thái game                      |
| `TutorialManager`    | Theo dõi tiến trình hướng dẫn                  |
| `MusicManager`       | Phát nhạc nền theo trạng thái                  |
| `InteractionManager` | Ưu tiên tương tác khi nhiều đối tượng gần nhau |
| `WaterTileChecker`   | Kiểm tra tile nước trên bản đồ                 |
| `ItemTooltip`        | Hiển thị tooltip vật phẩm                      |


---

## 📁 Cấu trúc thư mục

```
.
├── README.md                 # Tài liệu dự án
├── src/                      # Mã nguồn game (Godot project)
│   ├── project.godot         # Cấu hình dự án Godot
│   ├── scenes/               # Scene (.tscn): game, player, enemy, UI, ...
│   ├── scripts/              # Script GDScript
│   │   ├── Player/           # Logic người chơi
│   │   ├── Enemy/            # AI kẻ thù
│   │   ├── Animal/           # AI động vật
│   │   ├── Building/         # Công trình (lò, đe, cổng, rương)
│   │   ├── InventorySystem/  # Túi đồ, chế tạo, trang bị, tooltip
│   │   ├── Resource/         # Node tài nguyên & spawner
│   │   └── Global/           # Autoload: tutorial, âm nhạc, tương tác
│   ├── resources/            # Dữ liệu game (.tres): item, recipe, loot table
│   └── assets/               # Sprites, âm thanh, nhạc nền
└── thesis/                   # Báo cáo đồ án tốt nghiệp
    ├── doc/                  # Bản Word
    └── pdf/                  # Bản PDF
```

### Lớp vật lý 2D


| Layer                   | Mục đích                   |
| ----------------------- | -------------------------- |
| World                   | Địa hình, vật cản          |
| Player / Enemy / Animal | Thân thể nhân vật          |
| HitBox / HurtBox        | Vùng gây / nhận sát thương |
| World Item              | Vật phẩm trên bản đồ       |
| Pickup Range            | Phạm vi nhặt đồ            |
| Building                | Công trình đã xây          |


---

## 🎨 Tài nguyên bên thứ ba

Game sử dụng **tài nguyên miễn phí** từ hai nền tảng:


| Loại                                     | Nguồn                                       |
| ---------------------------------------- | ------------------------------------------- |
| **Hình ảnh** (sprite, tileset, icon, UI) | [itch.io](https://itch.io/game-assets/free) |
| **Âm thanh** (nhạc nền, hiệu ứng)        | [OpenGameArt.org](https://opengameart.org/) |


### 🖼️ Hình ảnh — itch.io


| Gói tài nguyên                                                                                                                           | Nội dung sử dụng trong game                                                                             |
| ---------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------- |
| [ComfyMattres Ultimate Survival Game Pack](https://comfymattres.itch.io/comfymattres-ultimate-survival-game-starter-pack) — ComfyMattres | Tileset 16x16, vật phẩm, thức ăn, quặng, lò nung, bàn chế tạo, đe, rương, công cụ & trang bị (Ult Pack) |
| [Forest Vegetation Pack (Lite)](https://mxtgames.itch.io/forest-vegetation-lite) — MXT Games                                             | Màn hình menu chính                                                                                     |
| [Pixel Art Top Down - Basic](https://cainos.itch.io/pixel-art-top-down-basic) — Cainos                                                   | Sprite cổng dịch chuyển                                                                                 |
| [Adventurer 2D Top-Down](https://xzany.itch.io/top-down-adventurer-character) — Mattz Art                                                | Nhân vật người chơi: idle, chạy, tấn công (Attack 1 & 2), hướng 4 chiều                                 |
| [32×32 Pixel Isometric Tiles](https://scrabling.itch.io/pixel-isometric-tiles) — scrabling                                               | Sprite động vật (hươu, sói)                                                                             |
| [RPG Worlds — Caves](https://szadiart.itch.io/rpg-worlds-ca) — Szadi art.                                                                | Tileset vùng mỏ                                                                                         |
| [Anvil's RPG Icons](https://ponkpixels.itch.io/anvil-icons) — Ponk                                                                       | Icon vũ khí, giáp, nhẫn                                                                                 |


### 🔊 Âm thanh — OpenGameArt.org


| Gói tài nguyên                                                                                 | Nội dung sử dụng trong game                                                 |
| ---------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------- |
| [Wild Land (Soundtrack)](https://opengameart.org/content/wild-land-soundtrack) — Fato Shadow   | Nhạc nền khám phá (`fato_shadow_-_wild_land`)                               |
| [Sunny Day Outside (Loop)](https://opengameart.org/content/sunny-day-outside-loop) — zeta.zero | Nhạc nền ban ngày (`sunnydayoutside`)                                       |
| Nhạc nền miễn phí khác trên OpenGameArt                                                        | Menu, chiến đấu, rừng, ambient (`forest_1`, `Battle_04`, `menu`, …)         |
| Hiệu ứng âm thanh miễn phí trên OpenGameArt                                                    | Bước chân, chặt cây, rèn đe, lò nung, nhặt đồ, mở rương, tấn công sói, v.v. |


---

## 🐛 Khắc phục sự cố

### ❓ Godot không mở được project

- Kiểm tra đã cài **Godot 4.7** (không dùng Godot 3.x)
- Import đúng file `src/project.godot`, không phải thư mục gốc repo

### ❓ Game báo lỗi renderer / DirectX

- Cập nhật driver card đồ họa
- Trong Godot: **Project → Project Settings → Rendering → Drivers → Windows** — thử đổi `d3d12` sang `vulkan` hoặc `gl_compatibility`

### ❓ Nút "Tiếp tục" bị mờ (disabled)

- Chưa có bản lưu — chọn **Chơi mới** trước, thoát game để tạo save
- Bản lưu nằm tại `user://savegame.sav` (thư mục userdata của Godot)

### ❓ Âm thanh / nhạc không phát

- Kiểm tra âm lượng trong **Cài đặt** (menu chính hoặc menu tạm dừng)
- Kiểm tra volume mixer hệ điều hành

### 🔍 Debug Mode

Bật debug hitbox/hurtbox trong Inspector của node Player hoặc Enemy (`show_hit_box`, `show_hurt_box`).

---

## 📞 Hỗ trợ

- **Sinh viên**: Hà Gia Lộc
- **MSSV**: 110122103 — Lớp DA22TTD
- **GitHub**: [HaGiaLoc](https://github.com/HaGiaLoc)

---

## 📚 Tài liệu tham khảo

- [Godot Engine Documentation](https://docs.godotengine.org/en/stable/)
- [GDScript Reference](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_basics.html)

---

> © 2025 Survival2D — Hà Gia Lộc. All rights reserved.

