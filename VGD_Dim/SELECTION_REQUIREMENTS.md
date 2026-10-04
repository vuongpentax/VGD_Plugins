# Yêu cầu hiện tại · 2026-10-02

- Chỉnh mẫu trong Model Info, dùng APPLY của plugin áp lên Dim/Text được chọn.
- Mẫu native gồm font, cỡ pt hoặc Height của Dim và kiểu Dim; không quy đổi mm sang pt.
- Endpoint riêng Dimension/Label; sau APPLY gán tag 000 DIM / 000 TEXT.
- Chọn trực tiếp Dim/Text, không quét toàn model/group/component.
- Không hộp thông báo hoàn tất, không chuyển chữ thành edge/mesh.
- Giữ VGD và style T+; chỉ sửa Dim/Text, không đổi Cabinet.

SU2022 Windows English bridge gọi nút Update selected. Ruby/bridge fixture đạt nhưng dispatch Win32 và thay font/Height native chưa được kiểm chứng.
