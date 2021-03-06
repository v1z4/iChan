import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:iChan/blocs/blocs.dart';
import 'package:iChan/models/thread_storage.dart';
import 'package:iChan/pages/thread/thread.dart';
import 'package:iChan/services/exports.dart';
import 'package:iChan/services/my.dart' as my;
import 'package:pull_to_refresh/pull_to_refresh.dart';

import 'favorites.dart';

class FavoritesList extends StatefulWidget {
  const FavoritesList();
  FavoritesListState createState() => FavoritesListState();
}

class FavoritesListState extends State<FavoritesList> {
  int _selectedTab;
  final _refreshController = RefreshController(initialRefresh: false);
  final SlidableController slidableController = SlidableController();

  @override
  void initState() {
    _selectedTab = my.prefs.getInt('favorites_tab', defaultValue: 0);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> data = [];

    return BlocConsumer<FavoriteBloc, FavoriteState>(
      listener: (context, state) {
        if (state is FavoriteReady) {
          _refreshController.refreshCompleted();
          // Haptic.lightImpact();`
        }
      },
      builder: (context, state) {
        final favsList = my.favs.favorites;

        if (favsList.isEmpty) {
          return Center(
              child: FaIcon(FontAwesomeIcons.ghost, size: 60, color: my.theme.inactiveColor));
        }

        if (favsList.length >= 5 && data.isEmpty) {
          data.add(favsHeader());
        }

        final List<Widget> favData = buildData(favsList, _selectedTab);
        return SmartRefresher(
            controller: _refreshController,
            onRefresh: () {
              Haptic.lightImpact();
              my.favoriteBloc.refreshManual();
            },
            child: CustomScrollView(slivers: data + favData));
      },
    );
  }

  SliverFixedExtentList favsHeader() {
    return SliverFixedExtentList(
      itemExtent: 54.0,
      delegate: SliverChildListDelegate(
        [
          CupertinoSegmentedControl(
            groupValue: _selectedTab,
            selectedColor: my.theme.primaryColor,
            unselectedColor: my.theme.backgroundColor,
            padding: const EdgeInsets.symmetric(
                vertical: Consts.sidePadding, horizontal: Consts.sidePadding),
            onValueChanged: (val) {
              setState(() {
                _selectedTab = val as int;
                my.prefs.put('favorites_tab', _selectedTab);
              });
            },
            children: const <int, Widget>{
              0: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text(
                    'All',
                    style: TextStyle(fontSize: 15.0),
                  )),
              1: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text(
                    'Top',
                    style: TextStyle(fontSize: 15.0),
                  )),
              2: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text(
                    'Unread',
                    style: TextStyle(fontSize: 15.0),
                  )),
            },
          )
        ],
      ),
    );
  }

  SliverPersistentHeader makeHeader(String title, {Platform platform}) {
    return SliverPersistentHeader(
      delegate: _SliverAppBarDelegate(
        minHeight: 35.0,
        maxHeight: 35.0,
        child: HoldableHint(
          enabled: title.startsWith('/') || title.contains(': '),
          onLongPress: () {
            final boardName = title.split(":")[1].trim().replaceAll('/', '');
            Routz.of(context).toBoard(Board(boardName, platform: platform));
          },
          holdChild: Container(
            color: my.theme.isDark
                ? my.theme.alphaBackground
                : my.theme.alphaBackground.withOpacity(0.7),
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.only(left: 10.0),
            child: Text(
              "TAP AND HOLD",
              style: TextStyle(
                color: my.theme.primaryColor,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          child: Container(
            color: my.theme.isDark
                ? my.theme.alphaBackground
                : my.theme.alphaBackground.withOpacity(0.7),
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.only(left: 10.0),
            child: Text(
              title,
              style: TextStyle(
                color: my.theme.foregroundMenuColor,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget makeItems(List<ThreadStorage> favs, BuildContext context, {String header = '/'}) {
    return SliverAnimatedList(
      key: UniqueKey(),
      initialItemCount: favs.length,
      itemBuilder: (context, index, animation) {
        final favItem =
            FavSliverItem(key: ValueKey(favs[index].id), fav: favs[index], header: header);

        return SizeTransition(
          sizeFactor: animation,
          child: Slidable.builder(
              key: Key("slideable-${favs[index].id}"),
              controller: slidableController,
              actionPane: const SlidableDrawerActionPane(),
              actionExtentRatio: 0.25,
              secondaryActionDelegate: SlideActionBuilderDelegate(
                actionCount: 1,
                builder: (context, i, slideAnimation, renderingMode) {
                  return IconSlideAction(
                    color: renderingMode == SlidableRenderingMode.slide
                        ? Colors.red.withOpacity(slideAnimation.value)
                        : Colors.red,
                    iconWidget: Container(
                      child: const Text(
                        'Delete',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    onTap: () {
                      my.favoriteBloc.favoriteDeleted(favs[index]);
                      setState(() {});
                    },
                  );
                },
              ),
              child: favItem),
        );
      },
    );
  }

  List<ThreadStorage> topList(List<ThreadStorage> favsList) {
    final firstList = favsList
        .where((f) => f.status != Status.deleted)
        .sortedBy((a, b) => b.visitedAt.compareTo(a.visitedAt))
        .first;

    final secondList = favsList
        .where((f) => f.status != Status.deleted)
        .sortedBy((a, b) => b.visits.compareTo(a.visits));

    return ([firstList] + secondList).toSet().toList();
  }

  List<Widget> buildData(List<ThreadStorage> favsList, selectedTab) {
    final List<Widget> _data = [];
    final platformNames = {
      Platform.dvach: "2ch",
      Platform.fourchan: "4chan",
      Platform.zchan: "Zchan",
    };

    final isTop = selectedTab == 1;
    final isUnread = selectedTab == 2;

    final filteredList = isTop ? topList(favsList) : favsList;
    final List<Board> boards = [];

    for (final e in filteredList) {
      if (boards.any((b) => b.id == e.boardName && b.platform == e.platform) == false) {
        boards.add(Board(e.boardName, platform: e.platform));
      }
    }

    // final boards = filteredList.map((e) => Board(e.boardName, platform: e.platform)).toSet().toList();

    final myThreads = filteredList.where((e) => e.isOp && e.status != Status.deleted).toList();

    if (myThreads.isNotEmpty) {
      const header = "My";
      _data.add(makeHeader(header));
      _data.add(makeItems(myThreads, context, header: header));
    }

    final List<ThreadStorage> best = [];
    if (isTop) {
      const header = "Top";

      for (final board in boards) {
        final thread = filteredList.sortedBy((a, b) => b.visits.compareTo(a.visits)).firstWhere(
            (e) => !e.isOp && e.boardName == board.id && e.platform == board.platform,
            orElse: () => null);

        if (thread != null && thread.visits >= 10 && thread.refresh) {
          best.add(thread);
        }
      }
      best.sort((a, b) => b.visits.compareTo(a.visits));
      if (best.length >= 3) {
        _data.add(makeHeader(header));
        _data.add(makeItems(best, context, header: header));
      }
    }

    if (isUnread) {
      final _favs = filteredList
          .where((e) => !e.isOp && e.unreadCount != 0 && e.status != Status.deleted)
          .toList();

      if (_favs.isNotEmpty) {
        const header = "Unread";
        _data.add(makeHeader(header));
        _data.add(makeItems(_favs, context, header: header));
      }
    }

    for (final board in boards) {
      bool unreadFilter(e) => !isUnread || e.unreadCount == 0;

      List<ThreadStorage> _favs = filteredList
          .where((e) =>
              !best.contains(e) &&
              !e.isOp &&
              e.boardName == board.id &&
              e.platform == board.platform &&
              unreadFilter(e))
          .toList();

      if (isTop) {
        _favs = _favs.sortedByNum((e) => -e.visits).take(5).toList();
      }

      if (_favs.isNotEmpty) {
        final h = my.prefs.platforms.length == 1
            ? "/${board.id}/"
            : "${platformNames[board.platform]}: /${board.id}/";
        _data.add(makeHeader(h, platform: board.platform));
        _data.add(makeItems(_favs, context));
      }
    }

    final savedThreads = my.favs.box.values.where((e) => e.isSaved).toList();

    if (savedThreads.isNotEmpty) {
      const header = "Saved";
      _data.add(makeHeader(header));
      _data.add(makeItems(savedThreads, context, header: header));
    }

    return _data;
  }
}

class HoldableHint extends StatefulWidget {
  const HoldableHint({
    Key key,
    this.child,
    this.holdChild,
    this.onLongPress,
    this.enabled,
  }) : super(key: key);

  final Widget child;
  final Widget holdChild;
  final Function onLongPress;
  final bool enabled;

  @override
  _HoldableHintState createState() => _HoldableHintState();
}

class _HoldableHintState extends State<HoldableHint> {
  bool tapped = false;

  void turnBack() {
    Future.delayed(0.5.seconds).then((value) => setState(() => tapped = false));
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return widget.child;
    }

    return GestureDetector(
      onLongPress: () {
        Haptic.mediumImpact();
        widget.onLongPress();
      },
      onTap: () {
        Haptic.lightImpact();
        setState(() {
          tapped = true;
        });
        turnBack();
      },
      child: tapped ? widget.holdChild : widget.child,
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate({
    @required this.minHeight,
    @required this.maxHeight,
    @required this.child,
  });
  final double minHeight;
  final double maxHeight;
  final Widget child;

  @override
  double get minExtent => minHeight;

  @override
  double get maxExtent => max(maxHeight, minHeight);

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return maxHeight != oldDelegate.maxHeight ||
        minHeight != oldDelegate.minHeight ||
        child != oldDelegate.child;
  }
}
