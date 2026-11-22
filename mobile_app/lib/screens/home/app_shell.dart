import 'package:audio2text_mobile/screens/auth/auth_screens.dart';
import 'package:audio2text_mobile/services/processing_screens.dart';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';

const _services = [
  _ServiceData(
    'Audio to Text',
    'Convert speech into accurate text.',
    Icons.graphic_eq_rounded,
    '10 DH',
  ),
  _ServiceData(
    'AI Summary',
    'Get the important ideas in seconds.',
    Icons.auto_awesome_rounded,
    '10 DH',
  ),
  _ServiceData(
    'Translation',
    'Translate your transcript into another language.',
    Icons.translate_rounded,
    '10 DH',
  ),
  _ServiceData(
    'Subtitles',
    'Prepare subtitles for your video.',
    Icons.subtitles_rounded,
    '10 DH',
  ),
  _ServiceData(
    'Meeting Notes',
    'Turn meetings into clear reports.',
    Icons.event_note_rounded,
    '10 DH',
  ),
  _ServiceData(
    'Key Points',
    'Extract tasks and important points.',
    Icons.checklist_rounded,
    '10 DH',
  ),
];

class _ServiceData {
  final String name;
  final String description;
  final IconData icon;
  final String price;

  const _ServiceData(this.name, this.description, this.icon, this.price);
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int selectedIndex = 0;

  final pages = const [
    HomeTab(),
    ServicesTab(),
    HistoryTab(),
    ChatTab(),
    ProfileTab(),
  ];

  final titles = const [
    'Overview',
    'Services',
    'My History',
    'Messages',
    'Profile',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            if (MediaQuery.sizeOf(context).width >= 850)
              NavigationRail(
                backgroundColor: AppTheme.surface,
                selectedIndex: selectedIndex,
                onDestinationSelected: (value) =>
                    setState(() => selectedIndex = value),
                labelType: NavigationRailLabelType.all,
                leading: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: _BrandMark(),
                ),
                destinations: const [
                  NavigationRailDestination(
                    icon: Icon(Icons.grid_view_rounded),
                    label: Text('Home'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.auto_awesome_rounded),
                    label: Text('Services'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.history_rounded),
                    label: Text('History'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.chat_bubble_outline_rounded),
                    label: Text('Chat'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.person_outline_rounded),
                    label: Text('Profile'),
                  ),
                ],
              ),
            Expanded(
              child: Column(
                children: [
                  _TopBar(
                    title: titles[selectedIndex],
                    onNotifications: () =>
                        _message(context, 'You are all caught up!'),
                  ),
                  Expanded(
                    child: IndexedStack(index: selectedIndex, children: pages),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: MediaQuery.sizeOf(context).width < 850
          ? NavigationBar(
              selectedIndex: selectedIndex,
              onDestinationSelected: (value) =>
                  setState(() => selectedIndex = value),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.grid_view_rounded),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.auto_awesome_rounded),
                  label: 'Services',
                ),
                NavigationDestination(
                  icon: Icon(Icons.history_rounded),
                  label: 'History',
                ),
                NavigationDestination(
                  icon: Icon(Icons.chat_bubble_outline_rounded),
                  label: 'Chat',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline_rounded),
                  label: 'Profile',
                ),
              ],
            )
          : null,
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF9B83FF), AppTheme.primary],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Icon(
        Icons.graphic_eq_rounded,
        color: Colors.white,
        size: 28,
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final String title;
  final VoidCallback onNotifications;

  const _TopBar({required this.title, required this.onNotifications});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 14, 18, 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF272D48))),
      ),
      child: Row(
        children: [
          if (MediaQuery.sizeOf(context).width < 850) ...[
            const _BrandMark(),
            const SizedBox(width: 13),
          ],
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          IconButton(
            onPressed: onNotifications,
            icon: const Icon(Icons.notifications_none_rounded),
            tooltip: 'Notifications',
          ),
          const CircleAvatar(
            radius: 18,
            backgroundColor: AppTheme.surfaceLight,
            child: Text(
              'A',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PageBody extends StatelessWidget {
  final Widget child;
  const _PageBody({required this.child});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(22),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: child,
        ),
      ),
    );
  }
}

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    return _PageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(25),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(25),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF44348E),
                  Color(0xFF211E48),
                  Color(0xFF142D40),
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'YOUR AI WORKSPACE',
                  style: TextStyle(
                    color: Color(0xFFC7B9FF),
                    letterSpacing: 2,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Make every word\ncount.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 31,
                    height: 1.15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Transform audio into useful content with AI.',
                  style: TextStyle(color: Color(0xFFD0CBEA)),
                ),
                const SizedBox(height: 22),
                FilledButton.icon(
                  onPressed: () => _message(
                    context,
                    'Choose a service from the Services tab.',
                  ),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Create new project'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF9B83FF),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 25),
          const _SectionTitle(
            'Your workspace',
            'A quick look at your activity',
          ),
          const SizedBox(height: 14),
          const Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _MetricCard(
                title: 'Total projects',
                value: '08',
                icon: Icons.folder_copy_outlined,
                color: AppTheme.primary,
              ),
              _MetricCard(
                title: 'Completed',
                value: '06',
                icon: Icons.task_alt_rounded,
                color: AppTheme.secondary,
              ),
              _MetricCard(
                title: 'In progress',
                value: '02',
                icon: Icons.pending_actions_rounded,
                color: Color(0xFFFFB45E),
              ),
            ],
          ),
          const SizedBox(height: 28),
          const _SectionTitle('Popular services', 'Choose what you need'),
          const SizedBox(height: 14),
          ..._services.take(3).map((service) => _ServiceTile(service: service)),
          const SizedBox(height: 25),
          const _SectionTitle('Recent activity', 'Your latest demo projects'),
          const SizedBox(height: 12),
          const _HistoryTile(
            name: 'Team meeting.mp3',
            date: 'Today · 10:42 AM',
            status: 'Completed',
          ),
          const _HistoryTile(
            name: 'Interview recording.wav',
            date: 'Yesterday · 04:15 PM',
            status: 'Processing',
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF272D48)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 18),
            Text(
              value,
              style: const TextStyle(
                fontSize: 27,
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              title,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ServicesTab extends StatelessWidget {
  const ServicesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return _PageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'AI services',
            style: TextStyle(
              color: Colors.white,
              fontSize: 27,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Powerful tools for your audio and content.',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 22),
          ..._services.map((service) => _ServiceTile(service: service)),
          const SizedBox(height: 15),
          const Text(
            'Preview prices: 10 DH per service. Final price and scope are confirmed before processing.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _ServiceTile extends StatelessWidget {
  final _ServiceData service;
  const _ServiceTile({required this.service});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: const Color(0xFF272D48)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(service.icon, color: const Color(0xFFB5A5FF)),
        ),
        title: Text(
          service.name,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(
            service.description,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              service.price,
              style: const TextStyle(
                color: AppTheme.secondary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 13,
              color: AppTheme.textSecondary,
            ),
          ],
        ),
        onTap: () => _showServiceDetails(context, service),
      ),
    );
  }
}

void _showServiceDetails(BuildContext context, _ServiceData service) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
    builder: (sheetContext) => Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(service.icon, color: AppTheme.secondary, size: 38),
          const SizedBox(height: 17),
          Text(
            service.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            service.description,
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 18),
          Text(
            'Price: ${service.price}',
            style: const TextStyle(
              color: AppTheme.secondary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                Navigator.pop(sheetContext);
                Navigator.pushNamed(context, ProcessingScreens.upload);
              },
              icon: const Icon(Icons.upload_file_rounded),
              label: const Text('Choose audio file'),
            ),
          ),
        ],
      ),
    ),
  );
}

class HistoryTab extends StatelessWidget {
  const HistoryTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const _PageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'My projects',
            style: TextStyle(
              color: Colors.white,
              fontSize: 27,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Track your recent audio tasks.',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
          SizedBox(height: 22),
          _HistoryTile(
            name: 'Team meeting.mp3',
            date: 'Today · 10:42 AM',
            status: 'Completed',
          ),
          _HistoryTile(
            name: 'Interview recording.wav',
            date: 'Yesterday · 04:15 PM',
            status: 'Processing',
          ),
          _HistoryTile(
            name: 'Lecture Arabic.m4a',
            date: '20 Nov · 02:30 PM',
            status: 'Completed',
          ),
          _HistoryTile(
            name: 'Podcast episode.mp3',
            date: '18 Nov · 11:20 AM',
            status: 'Failed',
          ),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final String name;
  final String date;
  final String status;

  const _HistoryTile({
    required this.name,
    required this.date,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final color = status == 'Completed'
        ? AppTheme.secondary
        : status == 'Failed'
        ? const Color(0xFFFF647C)
        : const Color(0xFFFFB45E);
    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFF272D48)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.audio_file_rounded,
            color: AppTheme.primary,
            size: 27,
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  date,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ChatTab extends StatefulWidget {
  const ChatTab({super.key});

  @override
  State<ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<ChatTab> {
  final controller = TextEditingController();
  final messages = <String>[
    'Welcome to Audio2Text AI support. How can we help you?',
  ];

  void send() {
    final value = controller.text.trim();
    if (value.isEmpty) return;
    setState(() {
      messages.add(value);
      controller.clear();
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(18),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AppTheme.primary,
                child: Icon(Icons.support_agent_rounded, color: Colors.white),
              ),
              SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Support team',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Preview conversation',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(18),
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final mine = index != 0;
              return Align(
                alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 290),
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: mine
                        ? const Color(0xFF5543B5)
                        : AppTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: Text(
                    messages[index],
                    style: const TextStyle(color: Colors.white, height: 1.4),
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  onSubmitted: (_) => send(),
                  decoration: const InputDecoration(
                    hintText: 'Write a message...',
                    prefixIcon: Icon(Icons.message_outlined),
                  ),
                ),
              ),
              const SizedBox(width: 9),
              IconButton.filled(
                onPressed: send,
                icon: const Icon(Icons.send_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  Map<String, dynamic>? _user;
  bool _isLoading = true;
  bool _isLoggingOut = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await AuthService.instance.getMe();

      if (!mounted) return;

      // Support both direct user data and {"user": {...}} responses.
      final userData = data['user'] is Map
          ? Map<String, dynamic>.from(data['user'] as Map)
          : data;

      setState(() {
        _user = userData;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _signOut() async {
    if (_isLoggingOut) return;

    setState(() => _isLoggingOut = true);

    String? logoutError;

    try {
      await AuthService.instance.logout();
    } catch (error) {
      logoutError = error.toString().replaceFirst('Exception: ', '');
    }

    if (!mounted) return;

    Navigator.pushNamedAndRemoveUntil(
      context,
      AuthScreens.login,
      (route) => false,
    );

    if (logoutError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Local session cleared. Server logout status: $logoutError',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = (_user?['full_name'] ?? 'User').toString();
    final email = (_user?['email'] ?? '').toString();
    final phone = (_user?['phone'] ?? '').toString();
    final role = (_user?['role'] ?? 'client').toString();

    return _PageBody(
      child: Column(
        children: [
          const SizedBox(height: 15),

          const CircleAvatar(
            radius: 43,
            backgroundColor: AppTheme.primary,
            child: Icon(Icons.person_rounded, color: Colors.white, size: 43),
          ),

          const SizedBox(height: 13),

          if (_isLoading)
            const CircularProgressIndicator(color: AppTheme.secondary)
          else if (_error != null)
            Column(
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: Colors.redAccent,
                  size: 28,
                ),
                const SizedBox(height: 8),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.textSecondary),
                ),
                TextButton(onPressed: _loadProfile, child: const Text('Retry')),
              ],
            )
          else ...[
            Text(
              name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 21,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 5),
            Text(email, style: const TextStyle(color: AppTheme.textSecondary)),
            if (phone.isNotEmpty) ...[
              const SizedBox(height: 5),
              Text(
                phone,
                style: const TextStyle(color: AppTheme.textSecondary),
              ),
            ],
            const SizedBox(height: 5),
            Text(
              role.toUpperCase(),
              style: const TextStyle(
                color: AppTheme.secondary,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
          ],

          const SizedBox(height: 28),

          _ProfileItem(
            icon: Icons.person_outline_rounded,
            title: 'Personal information',
            onTap: () => _message(context, 'Profile editing is coming soon.'),
          ),

          _ProfileItem(icon: Icons.language_rounded, title: 'Language'),

          _ProfileItem(
            icon: Icons.notifications_outlined,
            title: 'Notifications',
          ),

          _ProfileItem(
            icon: Icons.lock_outline_rounded,
            title: 'Privacy & security',
          ),

          _ProfileItem(
            icon: Icons.help_outline_rounded,
            title: 'Help & support',
          ),

          _ProfileItem(
            icon: Icons.logout_rounded,
            title: _isLoggingOut ? 'Signing out...' : 'Sign out',
            color: const Color(0xFFFF647C),
            onTap: _isLoggingOut ? null : _signOut,
          ),

          const SizedBox(height: 20),

          const Text(
            'Audio2Text AI',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _ProfileItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color? color;
  final VoidCallback? onTap;

  const _ProfileItem({
    required this.icon,
    required this.title,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final itemColor = color ?? AppTheme.textPrimary;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(15),
      ),
      child: ListTile(
        leading: Icon(icon, color: itemColor),
        title: Text(title, style: TextStyle(color: itemColor, fontSize: 14)),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          color: AppTheme.textSecondary,
        ),
        onTap: onTap ?? () => _message(context, '$title is coming soon.'),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;
  const _SectionTitle(this.title, this.subtitle);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 19,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
        ),
      ],
    );
  }
}

void _message(BuildContext context, String text) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}
