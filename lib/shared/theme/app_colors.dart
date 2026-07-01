import 'package:flutter/material.dart';
import 'package:openhearth_design/openhearth_design.dart';

class AppColors {
  AppColors._();

  // Furrow — tilled-earth ochre (primary accent). The ochre ramp is Furrow's
  // SIGNATURE, deliberately app-local — not a canonical OhColors token.
  static const furrow500 = Color(0xFFB07A2E);
  static const furrow600 = Color(0xFF8F6122);
  static const furrow700 = Color(0xFF6E4A19);

  // Linen — neutral ground. 50/900 match the canonical tokens exactly;
  // 100/200/700 are Furrow's own warmer mix and stay literal.
  static const linen50  = OhColors.linen50;
  static const linen100 = Color(0xFFF5F0E8);
  static const linen200 = Color(0xFFEBE3D4);
  static const linen700 = Color(0xFF7C6C55);
  static const linen900 = OhColors.linen900;

  // Progress (never red — yellow/orange when behind)
  static const onPace         = OhColors.sage500;
  static const slightlyBehind = Color(0xFFF5C842);
  static const behind         = Color(0xFFF5A623);

  // Warm dark surfaces (base matches the canonical hearth-dark surface base;
  // warmDark2 is Furrow's own and stays literal)
  static const warmDark  = OhColors.darkSurfaceBase;
  static const warmDark2 = Color(0xFF241508);

  // Badge + accent
  static const sunGold = Color(0xFFF5A623);
}
