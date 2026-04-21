import 'package:flutter/material.dart';

/// Global navigator for deep links (e.g. Stripe return) outside the widget subtree.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();
