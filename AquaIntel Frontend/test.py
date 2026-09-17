def check(path, lns):
    with open(path, 'r', encoding='utf-8', errors='replace') as f:
        lines = f.readlines()
    for l in lns:
        print(f'{path}:{l+1} -> {lines[l].strip().encode("ascii", "replace").decode("ascii")}')

check('lib/screens/scan/scan_screen.dart', [209])
check('lib/screens/copilot/copilot_screen.dart', [151, 200])
check('lib/screens/reports/reports_screen.dart', [156])
