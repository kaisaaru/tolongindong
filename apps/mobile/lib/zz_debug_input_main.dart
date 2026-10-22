// TEMP debug entry — delete after investigation.
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'features/household/household_models.dart';
import 'features/household/household_samples.dart';
import 'features/order/order_store.dart';
import 'features/order/payment_method_page.dart';
import 'main.dart';
import 'theme/app_typography.dart';

void main() {
  final prevOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    debugPrint('DEBUG FlutterError: ${details.exceptionAsString()}');
    prevOnError?.call(details);
  };
  PlatformDispatcher.instance.onError = (e, st) {
    debugPrint('DEBUG PlatformError: $e\n$st');
    return false;
  };
  final store = OrderStore.instance;
  HouseholdOrderDraft d(HouseholdService svc) => HouseholdOrderDraft(
    service: svc,
    address: HouseholdSamples.savedAddresses.first,
    helper: HouseholdSamples.helpers.first,
    hours: 2,
    widthM: 10,
    lengthM: 10,
    tools: ToolOption.provided,
  );
  final pay = HouseholdSamples.paymentMethods.first;
  store
    ..place(draft: d(HouseholdService.kamar), payment: pay)
    ..cancel()
    ..place(draft: d(HouseholdService.kamar), payment: pay)
    ..complete()
    ..place(draft: d(HouseholdService.rumah), payment: pay)
    ..complete()
    ..place(draft: d(HouseholdService.rumah), payment: pay);
  runApp(const _Debug(child: MyApp()));
  HardwareKeyboard.instance.addHandler((e) {
    if (e is KeyDownEvent) debugPrint('DEBUG key ${e.logicalKey.keyLabel}');
    return false;
  });
}

class _Debug extends StatefulWidget {
  const _Debug({required this.child});
  final Widget child;
  @override
  State<_Debug> createState() => _DebugState();
}

class _DebugState extends State<_Debug> {
  final _watched = Expando<bool>();
  int _n = 0;

  @override
  void initState() {
    super.initState();
    Timer.periodic(const Duration(milliseconds: 300), (_) {
      try {
        _scan();
        _poll();
      } catch (e) {
        debugPrint('DEBUG scan error: $e');
      }
    });
  }

  String _last = '';

  void _poll() {
    final f = File(
      '/private/tmp/claude-501/-Users-nanda-App-Dev-FluuterDev-tolongindong/84d98246-61f8-4426-9f3c-ed59d2e08ec0/scratchpad/cmd.txt',
    );
    if (!f.existsSync()) return;
    final cmd = f.readAsStringSync().trim();
    if (cmd.isEmpty || cmd == _last) return;
    _last = cmd;
    if (cmd.endsWith('PAYMENT')) {
      Navigator.of(_navContext()).push(
        MaterialPageRoute<void>(
          builder: (_) => PaymentMethodPage(
            selected: HouseholdSamples.paymentMethods[3],
            allowCashOnDelivery: true,
          ),
        ),
      );
      return;
    }
    final text = cmd.substring(cmd.indexOf(' tap ') + 5);
    Element? hit;
    void visit(Element e) {
      final w = e.widget;
      if (w is Text && w.data == text) hit = e;
      e.visitChildElements(visit);
    }

    context.visitChildElements(visit);
    var tapped = false;
    hit?.visitAncestorElements((a) {
      final w = a.widget;
      if (w is InkWell && w.onTap != null) {
        w.onTap!();
        tapped = true;
        return false;
      }
      if (w is GestureDetector && w.onTap != null) {
        w.onTap!();
        tapped = true;
        return false;
      }
      return true;
    });
    debugPrint('DEBUG cmd $cmd -> found=${hit != null} tapped=$tapped');
  }

  BuildContext _navContext() {
    late BuildContext found;
    var done = false;
    void visit(Element e) {
      if (done) return;
      if (e is StatefulElement && e.state is NavigatorState) {
        found = (e.state as NavigatorState).context;
        done = true;
        return;
      }
      e.visitChildElements(visit);
    }

    context.visitChildElements(visit);
    return found;
  }

  void _scan() {
    void visit(Element e) {
      if (e is StatefulElement && e.state is EditableTextState) {
        final s = e.state as EditableTextState;
        if (_watched[s] == null) {
          _watched[s] = true;
          final id = _n++;
          final route = ModalRoute.of(s.context)?.settings.name ??
              ModalRoute.of(s.context).runtimeType.toString();
          final hint = s.context
              .findAncestorWidgetOfExactType<TextField>()
              ?.decoration
              ?.hintText;
          debugPrint('DEBUG field#$id new route=$route hint=$hint');
          s.widget.controller.addListener(() {
            debugPrint('DEBUG field#$id value="${s.widget.controller.text}"');
          });
          s.widget.focusNode.addListener(() {
            debugPrint(
              'DEBUG field#$id focus=${s.widget.focusNode.hasFocus} '
              'mounted=${s.mounted}',
            );
          });
        }
      }
      e.visitChildElements(visit);
    }

    context.visitChildElements(visit);
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (e) => debugPrint('DEBUG down ${e.position}'),
    child: widget.child,
  );
}

const calibSpecs = <(String, FontWeight)>[
  ('Dalam Proses', FontWeight.w400),
  ('Dalam Proses', FontWeight.w500),
  ('Household', FontWeight.w400),
  ('Tiba dalam 30 menit', FontWeight.w600),
  ('Tiba dalam 30 menit', FontWeight.w700),
  ('Household - Rumah', FontWeight.w600),
  ('Household - Rumah', FontWeight.w700),
  ('10 Okt 2026', FontWeight.w400),
  ('Rp38.000', FontWeight.w400),
  ('Rp38.000', FontWeight.w500),
  ('Dibatalkan', FontWeight.w400),
  ('Dibatalkan', FontWeight.w500),
];

class CalibPage extends StatelessWidget {
  const CalibPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: Padding(
      padding: const EdgeInsets.fromLTRB(10, 60, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (t, w) in calibSpecs)
            SizedBox(
              height: 60,
              child: Text(
                t,
                maxLines: 1,
                softWrap: false,
                style: AppTypography.style(size: 30, weight: w),
              ),
            ),
        ],
      ),
    ),
  );
}
