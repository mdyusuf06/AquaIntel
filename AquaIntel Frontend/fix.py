def fix(path, fixes):
    with open(path, 'r', encoding='utf-8', errors='replace') as f:
        lines = f.readlines()
    for l, val in fixes.items():
        lines[l] = val + '\n'
    with open(path, 'w', encoding='utf-8') as f:
        f.writelines(lines)

fix('lib/screens/scan/scan_screen.dart', {
    209: "                  result.isComplete ? '? Processing complete' : 'Processing...',"
})
fix('lib/screens/copilot/copilot_screen.dart', {
    151: "                  Text('Listening in ${chat.language}...', style: AppTextStyles.body.copyWith(color: AppColors.danger, fontWeight: FontWeight.bold)),",
    200: "                          hintText: chat.isRecording ? 'Listening...' : 'Ask about detections, risk, or mission...',"
})
fix('lib/screens/reports/reports_screen.dart', {
    156: "      content: Text('Exporting $format report...'),"
})
