import 'dart:math';
import 'dart:ui';

import 'package:aves/model/image_entry.dart';
import 'package:aves/model/image_metadata.dart';
import 'package:aves/model/metadata_service.dart';
import 'package:aves/utils/constants.dart';
import 'package:aves/utils/geo_utils.dart';
import 'package:aves/widgets/common/fx/blurred.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:outline_material_icons/outline_material_icons.dart';
import 'package:provider/provider.dart';
import 'package:tuple/tuple.dart';

class FullscreenBottomOverlay extends StatefulWidget {
  final List<ImageEntry> entries;
  final int index;
  final EdgeInsets viewInsets, viewPadding;

  const FullscreenBottomOverlay({
    Key key,
    @required this.entries,
    @required this.index,
    this.viewInsets,
    this.viewPadding,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => _FullscreenBottomOverlayState();
}

class _FullscreenBottomOverlayState extends State<FullscreenBottomOverlay> {
  Future<OverlayMetadata> _detailLoader;
  ImageEntry _lastEntry;
  OverlayMetadata _lastDetails;

  static const innerPadding = EdgeInsets.symmetric(vertical: 4, horizontal: 8);

  ImageEntry get entry {
    final entries = widget.entries;
    final index = widget.index;
    return index < entries.length ? entries[index] : null;
  }

  @override
  void initState() {
    super.initState();
    _initDetailLoader();
  }

  @override
  void didUpdateWidget(FullscreenBottomOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    _initDetailLoader();
  }

  void _initDetailLoader() {
    _detailLoader = MetadataService.getOverlayMetadata(entry);
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: BlurredRect(
        child: Selector<MediaQueryData, Tuple3<double, EdgeInsets, EdgeInsets>>(
          selector: (c, mq) => Tuple3(mq.size.width, mq.viewInsets, mq.viewPadding),
          builder: (c, mq, child) {
            final mqWidth = mq.item1;
            final mqViewInsets = mq.item2;
            final mqViewPadding = mq.item3;

            final viewInsets = widget.viewInsets ?? mqViewInsets;
            final viewPadding = widget.viewPadding ?? mqViewPadding;
            final overlayContentMaxWidth = mqWidth - viewPadding.horizontal - innerPadding.horizontal;

            return Container(
              color: Colors.black26,
              padding: viewInsets + viewPadding.copyWith(top: 0),
              child: Padding(
                padding: innerPadding,
                child: FutureBuilder(
                  future: _detailLoader,
                  builder: (futureContext, AsyncSnapshot<OverlayMetadata> snapshot) {
                    if (snapshot.connectionState == ConnectionState.done && !snapshot.hasError) {
                      _lastDetails = snapshot.data;
                      _lastEntry = entry;
                    }
                    return _lastEntry == null
                        ? const SizedBox.shrink()
                        : _FullscreenBottomOverlayContent(
                            entry: _lastEntry,
                            details: _lastDetails,
                            position: '${widget.index + 1}/${widget.entries.length}',
                            maxWidth: overlayContentMaxWidth,
                          );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

const double _iconPadding = 8.0;
const double _iconSize = 16.0;
const double _interRowPadding = 2.0;
const double _subRowMinWidth = 300.0;

class _FullscreenBottomOverlayContent extends StatelessWidget {
  final ImageEntry entry;
  final OverlayMetadata details;
  final String position;
  final double maxWidth;

  const _FullscreenBottomOverlayContent({
    this.entry,
    this.details,
    this.position,
    this.maxWidth,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle(
      style: Theme.of(context).textTheme.bodyText2.copyWith(
        shadows: const [
          Shadow(
            color: Colors.black87,
            offset: Offset(0.5, 1.0),
          )
        ],
      ),
      softWrap: false,
      overflow: TextOverflow.fade,
      maxLines: 1,
      child: Selector<MediaQueryData, Orientation>(
        selector: (c, mq) => mq.orientation,
        builder: (c, orientation, child) {
          final twoColumns = orientation == Orientation.landscape && maxWidth / 2 > _subRowMinWidth;
          final subRowWidth = twoColumns ? min(_subRowMinWidth, maxWidth / 2) : maxWidth;
          final hasShootingDetails = details != null && !details.isEmpty;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: maxWidth,
                child: Text('$position – ${entry.title}', strutStyle: Constants.overflowStrutStyle),
              ),
              if (entry.hasGps)
                Container(
                  padding: const EdgeInsets.only(top: _interRowPadding),
                  width: subRowWidth,
                  child: _LocationRow(entry),
                ),
              if (twoColumns)
                Padding(
                  padding: const EdgeInsets.only(top: _interRowPadding),
                  child: Row(
                    children: [
                      Container(width: subRowWidth, child: _DateRow(entry)),
                      if (hasShootingDetails) Container(width: subRowWidth, child: _ShootingRow(details)),
                    ],
                  ),
                )
              else ...[
                Container(
                  padding: const EdgeInsets.only(top: _interRowPadding),
                  width: subRowWidth,
                  child: _DateRow(entry),
                ),
                if (hasShootingDetails)
                  Container(
                    padding: const EdgeInsets.only(top: _interRowPadding),
                    width: subRowWidth,
                    child: _ShootingRow(details),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _LocationRow extends StatelessWidget {
  final ImageEntry entry;

  const _LocationRow(this.entry);

  @override
  Widget build(BuildContext context) {
    String location;
    if (entry.isLocated) {
      location = entry.shortAddress;
    } else if (entry.hasGps) {
      location = toDMS(entry.latLng).join(', ');
    }
    return Row(
      children: [
        const Icon(OMIcons.place, size: _iconSize),
        const SizedBox(width: _iconPadding),
        Expanded(child: Text(location, strutStyle: Constants.overflowStrutStyle)),
      ],
    );
  }
}

class _DateRow extends StatelessWidget {
  final ImageEntry entry;

  const _DateRow(this.entry);

  @override
  Widget build(BuildContext context) {
    final date = entry.bestDate;
    final dateText = '${DateFormat.yMMMd().format(date)} at ${DateFormat.Hm().format(date)}';
    final resolution = '${entry.width} × ${entry.height}';
    return Row(
      children: [
        const Icon(OMIcons.calendarToday, size: _iconSize),
        const SizedBox(width: _iconPadding),
        Expanded(flex: 3, child: Text(dateText, strutStyle: Constants.overflowStrutStyle)),
        Expanded(flex: 2, child: Text(resolution, strutStyle: Constants.overflowStrutStyle)),
      ],
    );
  }
}

class _ShootingRow extends StatelessWidget {
  final OverlayMetadata details;

  const _ShootingRow(this.details);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(OMIcons.camera, size: _iconSize),
        const SizedBox(width: _iconPadding),
        Expanded(child: Text(details.aperture, strutStyle: Constants.overflowStrutStyle)),
        Expanded(child: Text(details.exposureTime, strutStyle: Constants.overflowStrutStyle)),
        Expanded(child: Text(details.focalLength, strutStyle: Constants.overflowStrutStyle)),
        Expanded(child: Text(details.iso, strutStyle: Constants.overflowStrutStyle)),
      ],
    );
  }
}
