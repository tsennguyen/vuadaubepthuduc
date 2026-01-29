import 'package:flutter/material.dart';

import '../data/planner_settings_repository.dart';

class SettingsNotificationsPage extends StatefulWidget {
  const SettingsNotificationsPage({super.key});

  @override
  State<SettingsNotificationsPage> createState() =>
      _SettingsNotificationsPageState();
}

class _SettingsNotificationsPageState extends State<SettingsNotificationsPage> {
  late final PlannerSettingsRepository _repository;
  late Stream<PlannerSettings> _stream;

  @override
  void initState() {
    super.initState();
    // TODO: Replace with Riverpod provider / DI if desired.
    _repository = FirestorePlannerSettingsRepository();
    _stream = _repository.watch();
  }

  final _options = const [15, 30, 60];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Thông báo kế hoạch ăn')),
      body: StreamBuilder<PlannerSettings>(
        stream: _stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _ErrorView(
              message: snapshot.error.toString(),
              onRetry: () => setState(() => _stream = _repository.watch()),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final settings = snapshot.data!;
          return ListView(
            children: [
              SwitchListTile(
                title: const Text('Nhắc nấu ăn theo kế hoạch'),
                value: settings.enabled,
                onChanged: (v) => _repository.update(
                  enabled: v,
                  minutesBefore: settings.minutesBefore,
                ),
              ),
              ListTile(
                title: const Text('Nhắc trước'),
                subtitle: Text('${settings.minutesBefore} phút'),
                trailing: DropdownButton<int>(
                  value: settings.minutesBefore,
                  items: _options
                      .map(
                        (m) => DropdownMenuItem<int>(
                          value: m,
                          child: Text('$m phút'),
                        ),
                      )
                      .toList(),
                  onChanged: settings.enabled
                      ? (v) {
                          if (v != null) {
                            _repository.update(
                              enabled: true,
                              minutesBefore: v,
                            );
                          }
                        }
                      : null,
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Bạn sẽ được nhắc trước thời gian bữa ăn đã lên kế hoạch (dựa trên plannedFor).',
                  style: TextStyle(color: Colors.black54),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Không tải được cài đặt.\n$message',
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }
}

