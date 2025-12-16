import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wortis/class/class.dart';
import 'package:wortis/pages/homepage.dart';
import 'package:wortis/class/theme_provider.dart';
import 'package:wortis/class/dataprovider.dart';
import 'package:intl/intl.dart';
import 'package:wortis/pages/homepage_dias.dart';

class NewsPage extends StatefulWidget {
  const NewsPage({super.key});

  @override
  _NewsPageState createState() => _NewsPageState();
}

class _NewsPageState extends State<NewsPage> {
  int? selectedIndex;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ConnectivityManager(context).initConnectivity();
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final dataProvider = Provider.of<AppDataProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Actualités',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => _returnToHomePage(),
        ),
        backgroundColor: const Color(0xFF006699),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => dataProvider.refreshNews(),
          ),
        ],
      ),
      body: Stack(
        children: [
          dataProvider.isLoading && dataProvider.news.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : dataProvider.error.isNotEmpty && dataProvider.news.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(dataProvider.error),
                          ElevatedButton(
                            onPressed: () => dataProvider.refreshNews(),
                            child: const Text('Réessayer'),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () => dataProvider.refreshNews(),
                      child: ListView.builder(
                        itemCount: dataProvider.news.length,
                        itemBuilder: (context, index) {
                          final item = dataProvider.news[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  selectedIndex =
                                      selectedIndex == index ? null : index;
                                });
                              },
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ClipRRect(
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(12),
                                    ),
                                    child: Image.network(
                                      item.media.thumbnail.url,
                                      height: 200,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                        return Container(
                                          height: 200,
                                          color: Colors.grey[300],
                                          child: const Center(
                                            child: Icon(Icons.error),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF006699),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                item.metadata.category.name,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                            const Spacer(),
                                            Text(
                                              _formatDate(DateTime.parse(item
                                                  .status
                                                  .publishedAt)), // Maintenant la date est déjà au bon format
                                              style: TextStyle(
                                                color: isDark
                                                    ? Colors.white60
                                                    : Colors.black54,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          item.title,
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black,
                                          ),
                                        ),
                                        if (selectedIndex != index) ...[
                                          const SizedBox(height: 8),
                                          Text(
                                            item.content.summary,
                                            style: TextStyle(
                                              color: isDark
                                                  ? Colors.white70
                                                  : Colors.black87,
                                              fontSize: 14,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                        if (selectedIndex == index) ...[
                                          const SizedBox(height: 16),
                                          Text(
                                            item.content.body,
                                            style: TextStyle(
                                              color: isDark
                                                  ? Colors.white70
                                                  : Colors.black87,
                                              fontSize: 16,
                                              height: 1.5,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
          if (dataProvider.isNewsLoading)
            Container(
              color: Colors.white.withOpacity(0.7),
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF006699)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _returnToHomePage() {
    final homeType = NavigationManager.getCurrentHomePage();

    if (homeType == 'HomePageDias') {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const HomePageDias()),
        (route) => false,
      );
    } else {
      final routeObserver = RouteObserver<PageRoute>();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
            builder: (context) => HomePage(routeObserver: routeObserver)),
        (route) => false,
      );
    }
  }

  String _formatDate(DateTime date) {
    try {
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inHours < 24) {
        if (difference.inHours == 0) {
          return "Il y a ${difference.inMinutes} minutes";
        }
        return "Il y a ${difference.inHours} heures";
      } else if (difference.inDays < 7) {
        return "Il y a ${difference.inDays} jours";
      } else {
        return DateFormat('dd/MM/yyyy').format(date);
      }
    } catch (e) {
      // En cas d'erreur de parsing, retourner une date par défaut
      return "Date non disponible";
    }
  }
}

// Modèles de données
class NewsItem {
  final String id;
  final String title;
  final String slug;
  final Content content;
  final Media media;
  final Metadata metadata;
  final Status status;

  NewsItem({
    required this.id,
    required this.title,
    required this.slug,
    required this.content,
    required this.media,
    required this.metadata,
    required this.status,
  });

  factory NewsItem.fromJson(Map<String, dynamic> json) {
    return NewsItem(
      id: json['_id'],
      title: json['title'],
      slug: json['slug'],
      content: Content.fromJson(json['content']),
      media: Media.fromJson(json['media']),
      metadata: Metadata.fromJson(json['metadata']),
      status: Status.fromJson(json['status']),
    );
  }
}

class Content {
  final String body;
  final String summary;
  final int readingTime;

  Content({
    required this.body,
    required this.summary,
    required this.readingTime,
  });

  factory Content.fromJson(Map<String, dynamic> json) {
    return Content(
      body: json['body'],
      summary: json['summary'],
      readingTime: json['readingTime'],
    );
  }
}

class Media {
  final Thumbnail thumbnail;
  final List<NewsImage> images;

  Media({
    required this.thumbnail,
    required this.images,
  });

  factory Media.fromJson(Map<String, dynamic> json) {
    return Media(
      thumbnail: Thumbnail.fromJson(json['thumbnail']),
      images: (json['images'] as List)
          .map((image) => NewsImage.fromJson(image))
          .toList(),
    );
  }
}

class Thumbnail {
  final String url;
  final String alt;
  final int width;
  final int height;

  Thumbnail({
    required this.url,
    required this.alt,
    required this.width,
    required this.height,
  });

  factory Thumbnail.fromJson(Map<String, dynamic> json) {
    return Thumbnail(
      url: json['url'],
      alt: json['alt'],
      width: json['width'],
      height: json['height'],
    );
  }
}

class NewsImage {
  final String url;
  final String alt;
  final String caption;
  final int width;
  final int height;

  NewsImage({
    required this.url,
    required this.alt,
    required this.caption,
    required this.width,
    required this.height,
  });

  factory NewsImage.fromJson(Map<String, dynamic> json) {
    return NewsImage(
      url: json['url'],
      alt: json['alt'],
      caption: json['caption'],
      width: json['width'],
      height: json['height'],
    );
  }
}

class Metadata {
  final Category category;
  final List<String> tags;

  Metadata({
    required this.category,
    required this.tags,
  });

  factory Metadata.fromJson(Map<String, dynamic> json) {
    return Metadata(
      category: Category.fromJson(json['category']),
      tags: List<String>.from(json['tags']),
    );
  }
}

class Author {
  final String name;

  Author({
    required this.name,
  });

  factory Author.fromJson(Map<String, dynamic> json) {
    return Author(
      name: json['name'],
    );
  }
}

class Category {
  final String name;

  Category({
    required this.name,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      name: json['name'],
    );
  }
}

class Status {
  final bool published;
  final bool featured;
  final String publishedAt;
  final String updatedAt;
  final String? expiresAt;

  Status({
    required this.published,
    required this.featured,
    required this.publishedAt,
    required this.updatedAt,
    this.expiresAt,
  });

  factory Status.fromJson(Map<String, dynamic> json) {
    String formatDateString(String dateStr) {
      try {
        // Utiliser intl pour parser la date au format GMT
        final DateTime parsed =
            DateFormat("EEE, dd MMM yyyy HH:mm:ss", "en_US").parse(dateStr);
        return parsed.toIso8601String();
      } catch (e) {
        return DateTime.now().toIso8601String();
      }
    }

    return Status(
      published: json['published'],
      featured: json['featured'],
      publishedAt: formatDateString(json['publishedAt']),
      updatedAt: formatDateString(json['updatedAt']),
      expiresAt: json['expiresAt'] != null
          ? formatDateString(json['expiresAt'])
          : null,
    );
  }
}
