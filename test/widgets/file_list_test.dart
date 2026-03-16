import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gif_converter/models/conversion_job.dart';
import 'package:gif_converter/widgets/file_list.dart';

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

void main() {
  group('FileList', () {
    late List<ConversionJob> jobs;
    int? removedIndex;
    int? editedIndex;
    int? selectedIndex;
    bool clearedAll = false;

    setUp(() {
      jobs = [
        ConversionJob(inputPath: '/videos/test1.mp4'),
        ConversionJob(inputPath: '/videos/test2.mov'),
      ];
      removedIndex = null;
      editedIndex = null;
      selectedIndex = null;
      clearedAll = false;
    });

    Widget buildWidget({int? selected, int targetFps = 30}) {
      return _wrap(FileList(
        jobs: jobs,
        selectedIndex: selected,
        onSelect: (i) => selectedIndex = i,
        onRemove: (i) => removedIndex = i,
        onEdit: (i) => editedIndex = i,
        onClearAll: () => clearedAll = true,
        targetFps: targetFps,
      ));
    }

    testWidgets('displays file count header', (tester) async {
      await tester.pumpWidget(buildWidget());
      expect(find.text('Files (2)'), findsOneWidget);
    });

    testWidgets('displays filenames from paths', (tester) async {
      await tester.pumpWidget(buildWidget());
      expect(find.text('test1.mp4'), findsOneWidget);
      expect(find.text('test2.mov'), findsOneWidget);
    });

    testWidgets('shows pending status text for pending jobs', (tester) async {
      await tester.pumpWidget(buildWidget());
      expect(find.text('Pending'), findsNWidgets(2));
    });

    testWidgets('shows progress indicator for converting job', (tester) async {
      jobs[0].status = ConversionJobStatus.converting;
      jobs[0].progress = 0.5;
      await tester.pumpWidget(buildWidget());

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('50%'), findsOneWidget);
    });

    testWidgets('shows error message for failed job', (tester) async {
      jobs[0].status = ConversionJobStatus.error;
      jobs[0].errorMessage = 'Encoding failed';
      await tester.pumpWidget(buildWidget());

      expect(find.text('Encoding failed'), findsOneWidget);
    });

    testWidgets('shows file size for done job', (tester) async {
      jobs[0].status = ConversionJobStatus.done;
      jobs[0].outputFileSize = 1536; // 1.5 KB
      await tester.pumpWidget(buildWidget());

      expect(find.text('1.5 KB'), findsOneWidget);
    });

    testWidgets('shows file size in MB for large files', (tester) async {
      jobs[0].status = ConversionJobStatus.done;
      jobs[0].outputFileSize = 2 * 1024 * 1024; // 2 MB
      await tester.pumpWidget(buildWidget());

      expect(find.text('2.00 MB'), findsOneWidget);
    });

    testWidgets('clear all button fires callback', (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.tap(find.text('Clear All'));
      expect(clearedAll, true);
    });

    testWidgets('remove button fires callback with correct index',
        (tester) async {
      await tester.pumpWidget(buildWidget());

      // Find close icons and tap the first one
      final closeIcons = find.byIcon(Icons.close);
      expect(closeIcons, findsNWidgets(2));
      await tester.tap(closeIcons.first);
      expect(removedIndex, 0);
    });

    testWidgets('edit button fires callback with correct index',
        (tester) async {
      await tester.pumpWidget(buildWidget());

      final editIcons = find.byIcon(Icons.tune);
      expect(editIcons, findsNWidgets(2));
      await tester.tap(editIcons.first);
      expect(editedIndex, 0);
    });

    testWidgets('tapping done job fires select callback', (tester) async {
      jobs[0].status = ConversionJobStatus.done;
      jobs[0].outputPath = '/videos/test1.gif';
      jobs[0].outputFileSize = 1024;
      await tester.pumpWidget(buildWidget());

      // Tap the row with the filename
      await tester.tap(find.text('test1.mp4'));
      expect(selectedIndex, 0);
    });

    testWidgets('shows fps warning badge when source fps is lower than target',
        (tester) async {
      jobs[0].sourceFps = 15;
      await tester.pumpWidget(buildWidget(targetFps: 30));

      expect(find.text('15 fps'), findsOneWidget);
    });

    testWidgets('no fps badge when source fps exceeds target', (tester) async {
      jobs[0].sourceFps = 60;
      await tester.pumpWidget(buildWidget(targetFps: 30));

      expect(find.text('60 fps'), findsNothing);
    });

    testWidgets('check icon shown for done status', (tester) async {
      jobs[0].status = ConversionJobStatus.done;
      jobs[0].outputFileSize = 100;
      await tester.pumpWidget(buildWidget());

      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('error icon shown for error status', (tester) async {
      jobs[0].status = ConversionJobStatus.error;
      await tester.pumpWidget(buildWidget());

      expect(find.byIcon(Icons.error), findsOneWidget);
    });

    testWidgets('schedule icon shown for pending status', (tester) async {
      await tester.pumpWidget(buildWidget());
      expect(find.byIcon(Icons.schedule), findsNWidgets(2));
    });
  });
}
