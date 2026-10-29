import 'package:flutter/material.dart';
import 'section_header.dart';

/// Groupe de réglages : un titre, puis des lignes dans une même carte,
/// séparées par un filet. Toutes les pages de réglages l'utilisent, pour
/// une présentation identique partout.
class SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const SettingsSection({super.key, required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final visible = children.where((c) => c is! SizedBox).toList();
    if (visible.isEmpty) return const SizedBox.shrink();
    final line = Theme.of(context).colorScheme.outlineVariant.withAlpha(110);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(title),
          Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < visible.length; i++) ...[
                  if (i > 0) Divider(height: 1, thickness: 1, indent: 64, color: line),
                  visible[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Une ligne de réglage : icône, libellé en mots simples, précision
/// facultative. Avec [onChanged], c'est un interrupteur.
class SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final Color? color;

  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
    this.color,
  });

  /// Interrupteur (mode sombre, empreinte…).
  static Widget toggle({
    required IconData icon,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) =>
      _SettingsSwitch(
          icon: icon, title: title, subtitle: subtitle, value: value, onChanged: onChanged);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: _LeadingIcon(icon, color: color ?? scheme.primary),
      title: Text(title, style: TextStyle(color: color)),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: trailing ??
          (onTap == null ? null : Icon(Icons.chevron_right, color: scheme.outline)),
      onTap: onTap,
    );
  }
}

class _SettingsSwitch extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsSwitch({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => SwitchListTile(
        secondary: _LeadingIcon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title),
        subtitle: subtitle == null ? null : Text(subtitle!),
        value: value,
        onChanged: onChanged,
      );
}

class _LeadingIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _LeadingIcon(this.icon, {required this.color});

  @override
  Widget build(BuildContext context) => Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withAlpha(24),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 20, color: color),
      );
}
