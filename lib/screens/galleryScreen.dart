import 'package:dio/dio.dart';
import 'package:drag_down_to_pop/drag_down_to_pop.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:grow_it/components/Tile.dart';
import 'package:grow_it/model/post.dart';
import 'package:grow_it/screens/detailScreen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:grow_it/util/randomWord.dart';
import 'package:material_floating_search_bar/material_floating_search_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GalleryScreen extends StatefulWidget {
  @override
  _GalleryScreenState createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  bool _isLoading = true;
  bool _isLastPage = false;
  ScrollController _scrollController;

  List<Post> posts = [];
  int page = 1;
  String search = "plant";
  FloatingSearchBarController searchController;
  Future<SharedPreferences> _prefs = SharedPreferences.getInstance();

  List<String> history = List<String>.filled(3, null, growable: false);

  Future<List<String>> getHistory() async {
    final SharedPreferences prefs = await _prefs;
    List<String> elements =
        prefs.getStringList('history') ?? List.from(["cars"]);
    return elements;
  }

  void setHistory() async {
    final SharedPreferences prefs = await _prefs;
    setState(() {
      prefs.setStringList("history", history);
    });
  }

  Future<dynamic> fetchData() async {
    var url = env['PIXABAYURL'];

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await Dio().get('$url&page=$page&q=$search');
      if (response.statusCode == 200) {
        final List t =
            response.data["hits"]; //dio does json decode automatically
        bool noMoreElements = t.length < 40;

        if (noMoreElements) {
          setState(() {
            _isLastPage = true;
          });
        }

        setState(
          () {
            page += noMoreElements ? 0 : 1;
            posts.addAll(t.map((item) => Post.fromJson(item)).toList());
            _isLoading = false;
          },
        );

        if (posts.length % 40 != 0) {
          Fluttertoast.showToast(
              msg: "Reached the last page.",
              toastLength: Toast.LENGTH_LONG,
              gravity: ToastGravity.BOTTOM,
              timeInSecForIosWeb: 4,
              backgroundColor: Colors.orange,
              textColor: Colors.white,
              fontSize: 16.0);
        }
      }
    } catch (e) {
      print(e);
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();

    _scrollController = new ScrollController(initialScrollOffset: 5.0)
      ..addListener(() => _scrollListener());
    fetchData();
  }

  void _scrollListener() {
    if (_scrollController.offset >=
            _scrollController.position.maxScrollExtent - 250 &&
        !_scrollController.position.outOfRange) {
      if (!_isLoading && !_isLastPage) {
        /* print("Should load more");
        print("Offset ${_scrollController.offset}");
        print("Max extent ${_scrollController.position.maxScrollExtent}"); */
        fetchData();
      }
      //print("reached bottom, should load more");
    }
  }

  _openDetail(context, index) {
    final route = ImageViewerPageRoute(
      builder: (context) => DetailScreen(
        posts: posts,
        pageController: new PageController(initialPage: index),
      ),
    );
    Navigator.push(context, route);
  }

  Widget buildFloatingSearchBar() {
    final isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;
    searchController = FloatingSearchBarController();

    getHistory().then(
      (value) => setState(
        () {
          history = value;
        },
      ),
    );

    return FloatingSearchBar(
      hint: 'Caută imagini...',

      controller: searchController,
      scrollPadding: const EdgeInsets.only(top: 16, bottom: 56),
      transitionDuration: const Duration(milliseconds: 600),
      transitionCurve: Curves.easeInOut,
      physics: const BouncingScrollPhysics(),
      axisAlignment: isPortrait ? 0.0 : -1.0,
      openAxisAlignment: 0.0,
      maxWidth: isPortrait ? 600 : 500,
      debounceDelay: const Duration(milliseconds: 100),
      clearQueryOnClose: false,
      onQueryChanged: (query) {
        // Call your model, bloc, controller here.
        setState(() {
          search = query;
        });
      },
      onSubmitted: (query) {
        searchController.close();
        setState(() {
          page = 1;
          if (!history.contains(query)) {
            if (history.length > 4) {
              history.insert(0, query);
              history.removeLast();
            } else {
              history.insert(0, query);
            }
          }
          posts.clear();
        });
        setHistory();
        fetchData();
      },
      // Specify a custom transition to be used for
      // animating between opened and closed stated.
      transition: CircularFloatingSearchBarTransition(),
      actions: [
        FloatingSearchBarAction(
          showIfOpened: false,
          child: CircularButton(
            icon: const Icon(Icons.delete_forever),
            onPressed: () {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: Text("Atenție"),
                    content: Text("Ștergi istoricul căutărilor?"),
                    actions: [
                      TextButton(
                        child: Text("Da"),
                        onPressed: () {
                          setState(() {
                            history.clear();
                            setHistory();
                          });
                          Navigator.of(context).pop();
                        },
                      ),
                      TextButton(
                        child: Text("Nu"),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      )
                    ],
                  );
                },
              );
            },
          ),
        ),
        FloatingSearchBarAction.searchToClear(
          showIfClosed: false,
        ),
      ],
      builder: (context, transition) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Material(
            color: Colors.white,
            elevation: 4.0,
            child: Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: history.asMap().entries.map((entry) {
                  int index = entry.key;

                  var w = GestureDetector(
                    onTap: () {
                      print("Tapped index $index");
                      searchController.close();
                      searchController.query = entry.value;
                      setState(() {
                        search = entry.value;
                        page = 1;
                        posts.clear();
                      });
                      fetchData();
                    },
                    child: Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 16,
                            ),
                            Icon(Icons.history),
                            SizedBox(
                              width: 16,
                            ),
                            Container(
                              alignment: Alignment.centerLeft,
                              height: 30,
                              child: Text("${entry.value}"),
                            ),
                          ],
                        ),
                        Divider(
                          thickness: 1,
                        ),
                      ],
                    ),
                  );
                  return w;
                }).toList(),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    return new Scaffold(
      backgroundColor: Colors.black,
      floatingActionButton: FloatingActionButton(
        // isExtended: true,
        child: Icon(Icons.repeat),
        backgroundColor: Colors.orange,
        onPressed: () {
          setState(() {
            search = getRandomWord();
            searchController.query = search;
            page = 1;
            posts.clear();
          });
          fetchData();
        },
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: Container(
              child: GridView.builder(
                itemCount: posts.length,
                controller: _scrollController,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: kIsWeb
                      ? (width > 1000
                          ? 4
                          : width > 600
                              ? 3
                              : 2)
                      : 2,
                  crossAxisSpacing: 5,
                  mainAxisSpacing: 5,
                ),
                itemBuilder: (BuildContext context, int index) {
                  return Tile(
                    index: index,
                    url: posts[index].largeImageURL,
                    callback: () => _openDetail(context, index),
                  );
                },
              ),
            ),
          ),
          buildFloatingSearchBar(),
        ],
      ),
    );
  }
}

class ImageViewerPageRoute extends MaterialPageRoute {
  ImageViewerPageRoute({@required WidgetBuilder builder})
      : super(builder: builder, maintainState: false);

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    return const DragDownToPopPageTransitionsBuilder()
        .buildTransitions(this, context, animation, secondaryAnimation, child);
  }

  @override
  bool canTransitionFrom(TransitionRoute previousRoute) {
    return false;
  }

  @override
  bool canTransitionTo(TransitionRoute nextRoute) {
    return false;
  }
}
