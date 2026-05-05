import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hopefulme_flutter/app/theme/app_theme.dart';
import 'package:hopefulme_flutter/core/network/image_url_resolver.dart';
import 'package:hopefulme_flutter/core/widgets/app_toast.dart';
import 'package:hopefulme_flutter/core/widgets/fullscreen_network_image_screen.dart';
import 'package:hopefulme_flutter/features/auth/models/user.dart';
import 'package:hopefulme_flutter/features/groups/data/group_repository.dart';
import 'package:hopefulme_flutter/features/groups/models/group_models.dart';
import 'package:hopefulme_flutter/features/messages/data/message_repository.dart';
import 'package:hopefulme_flutter/features/profile/data/profile_repository.dart';
import 'package:hopefulme_flutter/features/profile/presentation/profile_navigation.dart';
import 'package:hopefulme_flutter/features/updates/data/update_repository.dart';

class GroupInfoScreen extends StatefulWidget {
  const GroupInfoScreen({
    required this.group,
    required this.repository,
    required this.currentUser,
    required this.profileRepository,
    required this.messageRepository,
    required this.updateRepository,
    this.openMembersTab = false,
    super.key,
  });

  final AppGroup group;
  final GroupRepository repository;
  final User? currentUser;
  final ProfileRepository profileRepository;
  final MessageRepository messageRepository;
  final UpdateRepository updateRepository;
  final bool openMembersTab;

  @override
  State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {
  final ScrollController _scrollController = ScrollController();
  late AppGroup _group = widget.group;
  final List<GroupMemberInfo> _members = [];
  bool _isLoadingMembers = true;
  bool _isLoadingMoreMembers = false;
  bool _isUpdatingNotifications = false;
  bool _isLeaving = false;
  int _membersPage = 1;
  int _membersLastPage = 1;
  late bool _showMembersSection = widget.openMembersTab;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _refreshGroupSummary();
    if (_group.id != 1 && widget.openMembersTab) {
      _loadMembers();
    } else {
      _isLoadingMembers = false;
    }
  }

  Future<void> _refreshGroupSummary() async {
    try {
      final latest = await widget.repository.fetchGroup(_group.id);
      if (!mounted) return;
      setState(() => _group = latest);
    } catch (_) {
      // Keep existing snapshot if refresh fails.
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 180 &&
        !_isLoadingMoreMembers &&
        _membersPage < _membersLastPage) {
      _loadMembers(loadMore: true);
    }
  }

  Future<void> _loadMembers({bool loadMore = false}) async {
    if (loadMore && (_isLoadingMoreMembers || _membersPage >= _membersLastPage)) {
      return;
    }
    if (loadMore) {
      setState(() => _isLoadingMoreMembers = true);
    }
    try {
      final targetPage = loadMore ? _membersPage + 1 : 1;
      final page = await widget.repository.fetchMembers(_group.id, page: targetPage);
      if (!mounted) return;
      setState(() {
        if (loadMore) {
          _members.addAll(page.items);
        } else {
          _members
            ..clear()
            ..addAll(page.items);
        }
        _membersPage = page.currentPage;
        _membersLastPage = page.lastPage;
      });
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMembers = false;
          _isLoadingMoreMembers = false;
        });
      }
    }
  }

  Future<void> _toggleNotifications() async {
    if (_isUpdatingNotifications) return;
    setState(() => _isUpdatingNotifications = true);
    try {
      final updated = await widget.repository.toggleNotifications(
        _group.id,
        enabled: !_group.notificationsEnabled,
      );
      if (!mounted) return;
      setState(() => _group = updated);
    } catch (error) {
      if (!mounted) return;
      AppToast.error(context, error.toString());
    } finally {
      if (mounted) setState(() => _isUpdatingNotifications = false);
    }
  }

  Future<void> _leaveGroup() async {
    if (_group.isOwner || _isLeaving) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Exit group?'),
        content: Text('Are you sure you want to leave ${_group.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Exit'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _isLeaving = true);
    try {
      await widget.repository.leaveGroup(_group.id);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      AppToast.error(context, error.toString());
    } finally {
      if (mounted) setState(() => _isLeaving = false);
    }
  }

  String _formatCount(int count) {
    if (count < 1000) return '$count';
    if (count < 1_000_000) {
      final v = count / 1000;
      return '${(v >= 10 ? v.toStringAsFixed(0) : v.toStringAsFixed(1)).replaceAll('.0', '')}k';
    }
    final v = count / 1_000_000;
    return '${(v >= 10 ? v.toStringAsFixed(0) : v.toStringAsFixed(1)).replaceAll('.0', '')}m';
  }

  String _slugify(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'-+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');

  String _buildGroupUrl() {
    final slug = _slugify(_group.name);
    final path = slug.isEmpty ? '/groups/${_group.id}' : '/groups/${_group.id}-$slug';
    return 'https://ahopefulme.com$path';
  }

  Future<void> _copyGroupLink() async {
    await Clipboard.setData(ClipboardData(text: _buildGroupUrl()));
    if (!mounted) return;
    AppToast.info(context, 'Group link copied to clipboard');
  }

  // Returns initials from a display name
  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (parts[0].isNotEmpty) return parts[0][0].toUpperCase();
    return '?';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Scaffold(
      backgroundColor: colors.scaffold,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Group Info', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        controller: _scrollController,
        padding: EdgeInsets.zero,
        children: [
          _buildHeroBanner(colors),
          if (_group.id != 1) ...[
            const SizedBox(height: 12),
            _buildStatsStrip(colors),
          ],
          const SizedBox(height: 12),
          _buildActionsCard(colors),
          if (_group.id != 1) ...[
            const SizedBox(height: 12),
            _buildMembersCard(colors),
          ],
          if (!_group.isOwner && _group.id != 1) ...[
            const SizedBox(height: 12),
            _buildExitButton(colors),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── Hero Banner ────────────────────────────────────────────────────────────

  Widget _buildHeroBanner(dynamic colors) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.brandStrong, colors.brand],
        ),
      ),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 72,
        left: 20,
        right: 20,
        bottom: 24,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _buildGroupAvatar(),
          const SizedBox(width: 14),
          Expanded(child: _buildGroupTitle()),
        ],
      ),
    );
  }

  Widget _buildGroupAvatar() {
    return GestureDetector(
      onTap: _group.photoUrl.isEmpty
          ? null
          : () => FullscreenNetworkImageScreen.show(
                context,
                imageUrl: ImageUrlResolver.resolveOriginal(_group.photoUrl),
                authorName: _group.name,
              ),
      child: Container(
        width: 68,
        height: 68,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.5), width: 2.5),
          color: Colors.white.withOpacity(0.15),
        ),
        child: ClipOval(
          child: _group.photoUrl.isNotEmpty
              ? Image.network(
                  ImageUrlResolver.avatar(_group.photoUrl, size: 136),
                  fit: BoxFit.cover,
                )
              : Center(
                  child: Text(
                    _initials(_group.name),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildGroupTitle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _group.name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (_group.info.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            _group.info,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
        if (_group.category.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                ),
                child: Text(
                  _group.category.trim(),
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
              const Spacer(),
              Text(
                'Group on Hopefulme',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 9.5,
                  fontWeight: FontWeight.w500,
                  height: 1.0,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  // ── Stats Strip ────────────────────────────────────────────────────────────

  Widget _buildStatsStrip(dynamic colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border.withOpacity(0.15)),
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              _buildStat(_formatCount(_group.membersCount), 'Members'),
              _buildStatDivider(colors),
         //     _buildStat(_formatCount(_group.messagesCount), 'Messages'),
              _buildStatDivider(colors),
              _buildStat('Active', 'Status'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStat(String value, String label) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatDivider(dynamic colors) {
    return Container(width: 0.5, color: colors.border.withOpacity(0.2));
  }

  // ── Actions Card ───────────────────────────────────────────────────────────

  Widget _buildActionsCard(dynamic colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border.withOpacity(0.15)),
        ),
        child: Column(
          children: [
            _buildActionTile(
              icon: Icons.link_rounded,
              title: 'Group link',
              subtitle: _buildGroupUrl(),
              onTap: _copyGroupLink,
              trailing: const Icon(Icons.content_copy_rounded, size: 16),
              colors: colors,
            ),
            _buildDivider(colors),
            _buildNotificationTile(colors),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Widget trailing,
    required dynamic colors,
    Color? iconColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            _buildIconContainer(icon, iconColor ?? colors.brand, colors),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing,
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationTile(dynamic colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _buildIconContainer(Icons.notifications_rounded, colors.brand, colors),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Notifications',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text('Get notified of group activity',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              ],
            ),
          ),
          Switch.adaptive(
            value: _group.notificationsEnabled,
            activeColor: colors.brand,
            onChanged: _isUpdatingNotifications ? null : (_) => _toggleNotifications(),
          ),
        ],
      ),
    );
  }

  Widget _buildIconContainer(IconData icon, Color color, dynamic colors) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 18, color: color),
    );
  }

  // ── Members Card ───────────────────────────────────────────────────────────

  Widget _buildMembersCard(dynamic colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border.withOpacity(0.15)),
        ),
        child: Column(
          children: [
            _buildMembersHeader(colors),
            if (_showMembersSection) _buildMembersBody(colors),
          ],
        ),
      ),
    );
  }

  Widget _buildMembersHeader(dynamic colors) {
    return InkWell(
      onTap: () {
        setState(() => _showMembersSection = !_showMembersSection);
        if (_showMembersSection &&
            _members.isEmpty &&
            !_isLoadingMembers &&
            !_isLoadingMoreMembers) {
          _loadMembers();
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            _buildIconContainer(Icons.group_rounded, colors.brand, colors),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Group members',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(
                    '${_formatCount(_group.membersCount)} members',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
            AnimatedRotation(
              turns: _showMembersSection ? 0.5 : 0,
              duration: const Duration(milliseconds: 200),
              child: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMembersBody(dynamic colors) {
    return Column(
      children: [
        _buildDivider(colors),
        if (_isLoadingMembers)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          )
        else ...[
          ..._members.map((member) => _buildMemberTile(member, colors)),
          if (_isLoadingMoreMembers)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ],
    );
  }

  Widget _buildMemberTile(GroupMemberInfo member, dynamic colors) {
    final canRemove = (_group.isOwner || _group.isAdminMember) &&
        !member.isOwner &&
        member.id != widget.currentUser?.id;

    return InkWell(
      onTap: () async {
        final username = member.username.trim();
        if (username.isEmpty) return;
        await openUserProfile(
          context,
          profileRepository: widget.profileRepository,
          messageRepository: widget.messageRepository,
          updateRepository: widget.updateRepository,
          currentUser: widget.currentUser,
          username: username,
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            _buildMemberAvatar(member),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.displayName,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    member.username.trim().isEmpty
                        ? ''
                        : '@${member.username.trim()}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
            _buildRoleBadge(member),
            if (canRemove) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _confirmRemoveMember(member),
                child: const Icon(
                  Icons.remove_circle_outline_rounded,
                  size: 18,
                  color: Colors.red,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMemberAvatar(GroupMemberInfo member) {
    final avatarColors = _avatarColorFor(member.id);
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: avatarColors.$1,
      ),
      child: ClipOval(
        child: member.photoUrl.isNotEmpty
            ? Image.network(
                ImageUrlResolver.avatar(member.photoUrl, size: 76),
                fit: BoxFit.cover,
              )
            : Center(
                child: Text(
                  _initials(member.displayName),
                  style: TextStyle(
                    color: avatarColors.$2,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildRoleBadge(GroupMemberInfo member) {
    final colors = context.appColors;
    if (member.isOwner) {
      return _rolePill('Owner', const Color(0xFFEEEDFE), const Color(0xFF3C3489));
    } else if (member.isAdmin) {
      return _rolePill(
        'Admin',
        colors.brand.withOpacity(0.14),
        colors.brandStrong,
      );
    }
    return const SizedBox.shrink();
  }

  Widget _rolePill(String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // Returns (background, text) colors for avatar based on member id
  (Color, Color) _avatarColorFor(int id) {
    final palettes = [
      (const Color(0xFFEEEDFE), const Color(0xFF3C3489)),
      (const Color(0xFFE1F5EE), const Color(0xFF085041)),
      (const Color(0xFFFAECE7), const Color(0xFF712B13)),
      (const Color(0xFFE6F1FB), const Color(0xFF0C447C)),
      (const Color(0xFFFBEAF0), const Color(0xFF72243E)),
      (const Color(0xFFEAF3DE), const Color(0xFF27500A)),
    ];
    return palettes[id % palettes.length];
  }

  Future<void> _confirmRemoveMember(GroupMemberInfo member) async {
    final role = member.isAdmin ? 'admin' : 'member';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove member?'),
        content: Text(
            'Remove ${member.displayName} ($role) from this group?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.repository.removeMember(_group.id, member.id);
      if (!mounted) return;
      setState(() {
        _members.removeWhere((m) => m.id == member.id);
        _group = _group.copyWith(
          membersCount: (_group.membersCount - 1).clamp(0, 1 << 30),
        );
      });
      AppToast.success(context, 'Member removed');
    } catch (error) {
      if (!mounted) return;
      AppToast.error(context, error.toString());
    }
  }

  // ── Exit Button ────────────────────────────────────────────────────────────

  Widget _buildExitButton(dynamic colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: OutlinedButton.icon(
        onPressed: _isLeaving ? null : _leaveGroup,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.red,
          side: const BorderSide(color: Colors.red, width: 0.8),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: _isLeaving
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.red),
              )
            : const Icon(Icons.exit_to_app_rounded, size: 18),
        label: const Text('Exit group',
            style: TextStyle(fontWeight: FontWeight.w500)),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Widget _buildDivider(dynamic colors) {
    return Divider(
      height: 0.5,
      thickness: 0.5,
      color: colors.border.withOpacity(0.15),
    );
  }
}
