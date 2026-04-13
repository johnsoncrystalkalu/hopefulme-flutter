import 'package:hopefulme_flutter/features/auth/data/auth_repository.dart';
import 'package:hopefulme_flutter/core/network/api_client.dart';
import 'package:hopefulme_flutter/core/storage/page_cache.dart';
import 'package:hopefulme_flutter/features/content/models/content_detail.dart';
import 'package:image_picker/image_picker.dart';

class ContentRepository {
  ContentRepository(this._authRepository, {PageCache? cache})
    : _cache = cache ?? PageCache();

  static const List<String> blogTags = <String>[
    'Motivation',
    'Inspiration',
    'Hope',
    'Salvation',
    'Love',
    'Faith',
    'Grace',
    'Poetry',
    'Prayer',
    'Education',
    'Success',
    'Philosophy',
    'Relationships',
    'Proverbs',
  ];

  final AuthRepository _authRepository;
  final PageCache _cache;

  Future<ContentDetail> fetchPost(int id, {int commentPage = 1}) async {
    final key = 'post:$id:comments:$commentPage';
    try {
      final response = await _authRepository.get(
        'post/$id',
        queryParameters: commentPage > 1
            ? <String, dynamic>{'comment_page': commentPage}
            : null,
      );
      await _cache.save(key, response);
      return ContentDetail.fromApi(
        response['post'] as Map<String, dynamic>? ?? <String, dynamic>{},
        kind: 'post',
      );
    } catch (error) {
      final cached = await _cache.read(key);
      if (cached != null) {
        return ContentDetail.fromApi(
          cached['post'] as Map<String, dynamic>? ?? <String, dynamic>{},
          kind: 'post',
        );
      }
      rethrow;
    }
  }

  Future<ContentDetail> fetchBlog(int id, {int commentPage = 1}) async {
    final key = 'blog:$id:comments:$commentPage';
    try {
      final response = await _authRepository.get(
        'blogs/$id',
        queryParameters: commentPage > 1
            ? <String, dynamic>{'comment_page': commentPage}
            : null,
      );
      await _cache.save(key, response);
      return ContentDetail.fromApi(
        response['blog'] as Map<String, dynamic>? ?? <String, dynamic>{},
        kind: 'blog',
      );
    } catch (error) {
      final cached = await _cache.read(key);
      if (cached != null) {
        return ContentDetail.fromApi(
          cached['blog'] as Map<String, dynamic>? ?? <String, dynamic>{},
          kind: 'blog',
        );
      }
      rethrow;
    }
  }

  Future<InspirationDetail> fetchInspiration(int id) async {
    final response = await _authRepository.get('inspire/$id');
    return InspirationDetail.fromApi(
      response['inspiration'] as Map<String, dynamic>? ?? <String, dynamic>{},
    );
  }

  Future<InspirationPage> fetchInspirationInbox({int page = 1}) async {
    final key = 'inspire-inbox:$page';
    try {
      final response = await _authRepository.get(
        'inspire/inbox',
        queryParameters: {'page': page},
      );
      await _cache.save(key, response);
      return InspirationPage.fromApi(response);
    } catch (error) {
      final cached = await _cache.read(key);
      if (cached != null) {
        return InspirationPage.fromApi(cached);
      }
      rethrow;
    }
  }

  Future<ContentComment> addComment({
    required String kind,
    required int contentId,
    required String comment,
  }) async {
    final response = await _authRepository.post(
      'comments',
      body: {
        'commentable_type': kind,
        'commentable_id': contentId,
        'comment': comment,
      },
    );

    return ContentComment.fromJson(
      response['comment'] as Map<String, dynamic>? ?? <String, dynamic>{},
    );
  }

  Future<ContentCommentReply> addCommentReply({
    required int commentId,
    required String comment,
  }) async {
    final response = await _authRepository.post(
      'comments/$commentId/replies',
      body: {'comment': comment},
    );

    return ContentCommentReply.fromJson(
      response['reply'] as Map<String, dynamic>? ?? <String, dynamic>{},
    );
  }

  Future<ContentDetail> createBlog({
    required String title,
    required String content,
    required String tag,
    required String label,
    XFile? photo,
  }) async {
    final response = photo == null
        ? await _authRepository.post(
            'blogs',
            body: {
              'title': title,
              'content': content,
              'tag': tag,
              'label': label,
            },
          )
        : await _authRepository.postMultipart(
            'blogs',
            fields: {
              'title': title,
              'content': content,
              'tag': tag,
              'label': label,
            },
            files: <ApiMultipartFile>[
              ApiMultipartFile(
                field: 'photo',
                filename: photo.name,
                bytes: await photo.readAsBytes(),
              ),
            ],
          );

    return ContentDetail.fromApi(
      response['blog'] as Map<String, dynamic>? ?? <String, dynamic>{},
      kind: 'blog',
    );
  }

  Future<ContentDetail> updateBlog({
    required int blogId,
    required String title,
    required String content,
    required String tag,
    required String label,
    XFile? photo,
    bool removePhoto = false,
  }) async {
    final response = (photo != null || removePhoto)
        ? await _authRepository.putMultipart(
            'blogs/$blogId',
            fields: {
              'title': title,
              'content': content,
              'tag': tag,
              'label': label,
              if (removePhoto) 'remove_photo': '1',
            },
            files: photo == null
                ? const <ApiMultipartFile>[]
                : <ApiMultipartFile>[
                    ApiMultipartFile(
                      field: 'photo',
                      filename: photo.name,
                      bytes: await photo.readAsBytes(),
                    ),
                  ],
          )
        : await _authRepository.put(
            'blogs/$blogId',
            body: {
              'title': title,
              'content': content,
              'tag': tag,
              'label': label,
            },
          );

    return ContentDetail.fromApi(
      response['blog'] as Map<String, dynamic>? ?? <String, dynamic>{},
      kind: 'blog',
    );
  }

  Future<void> deleteBlog(int blogId) async {
    await _authRepository.delete('blogs/$blogId');
  }
}
