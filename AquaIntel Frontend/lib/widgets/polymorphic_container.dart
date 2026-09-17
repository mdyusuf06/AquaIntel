import 'package:flutter/material.dart';

class PolymorphicContainer extends StatelessWidget {
  final Widget child;
  final bool isExpanded;
  final double expandedWidth;
  final double expandedHeight;
  final double collapsedWidth;
  final double collapsedHeight;
  final double expandedRadius;
  final double collapsedRadius;
  final Duration duration;
  final Decoration? expandedDecoration;
  final Decoration? collapsedDecoration;

  const PolymorphicContainer({
    super.key,
    required this.child,
    required this.isExpanded,
    this.expandedWidth = 300,
    this.expandedHeight = 400,
    this.collapsedWidth = 60,
    this.collapsedHeight = 60,
    this.expandedRadius = 16.0,
    this.collapsedRadius = 30.0,
    this.duration = const Duration(milliseconds: 400),
    this.expandedDecoration,
    this.collapsedDecoration,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: duration,
      curve: Curves.fastOutSlowIn,
      width: isExpanded ? expandedWidth : collapsedWidth,
      height: isExpanded ? expandedHeight : collapsedHeight,
      decoration: isExpanded 
          ? (expandedDecoration ?? BoxDecoration(borderRadius: BorderRadius.circular(expandedRadius)))
          : (collapsedDecoration ?? BoxDecoration(borderRadius: BorderRadius.circular(collapsedRadius))),
      child: AnimatedSize(
        duration: duration,
        curve: Curves.fastOutSlowIn,
        child: child,
      ),
    );
  }
}
