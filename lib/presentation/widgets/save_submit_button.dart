import 'package:flutter/material.dart';

/// Nút bấm thực thi Lưu / Cập nhật giao dịch.
class SaveSubmitButton extends StatelessWidget {
  /// Trạng thái đang gửi yêu cầu (khóa nút bấm và hiện progress).
  final bool isSubmitting;

  /// Xác định đang ở chế độ sửa hay tạo mới.
  final bool isEditing;

  /// Callback khi nhấn nút Lưu.
  final VoidCallback onPressed;

  /// Khởi tạo [SaveSubmitButton].
  const SaveSubmitButton({
    super.key,
    required this.isSubmitting,
    required this.isEditing,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: isSubmitting ? null : onPressed,
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
      ),
      child: isSubmitting
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.white,
              ),
            )
          : Text(
              isEditing ? 'Cập nhật giao dịch' : 'Lưu giao dịch',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
    );
  }
}
