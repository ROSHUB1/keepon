import '../../../core/widgets/glyph_icon.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_icons.dart';
import '../../../shared/models/protection_config.dart';

Glyph moduleIcon(ModuleId id) => switch (id) {
      ModuleId.motion => AppIcons.motion,
      ModuleId.charger => AppIcons.charger,
      ModuleId.headphones => AppIcons.headphones,
      ModuleId.sim => AppIcons.sim,
      ModuleId.connectivity => AppIcons.network,
    };
