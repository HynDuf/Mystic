import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:get_it/get_it.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mystic/helpers/mediaitem_converter.dart';
import 'package:mystic/screens/player.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:path_provider/path_provider.dart';

// ignore: avoid_classes_with_only_static_members
class PlayerInvoke {
  static final AudioPlayerHandler audioHandler = GetIt.I<AudioPlayerHandler>();

  static Future<void> init({
    required List songsList,
    required int index,
    bool fromMiniplayer = false,
    bool? isOffline,
    bool recommend = true,
    bool fromDownloads = false,
    bool shuffle = false,
    String? playlistBox,
  }) async {
    final globalIndex = index < 0 ? 0 : index;
    var offline = isOffline;
    final finalList = songsList.toList();
    if (shuffle) finalList.shuffle();
    if (offline == null) {
      if (audioHandler.mediaItem.value?.extras!['url'].startsWith('http')
          as bool) {
        offline = false;
      } else {
        offline = true;
      }
    } else {
      offline = offline;
    }

    if (!fromMiniplayer) {
      if (!Platform.isAndroid) {
        // Don't know why but it fixes the playback issue with iOS Side
        unawaited(audioHandler.stop());
      }
      if (offline) {
        fromDownloads
            ? setDownValues(finalList, globalIndex)
            : (Platform.isWindows || Platform.isLinux)
                ? setOffDesktopValues(finalList, globalIndex)
                : setOffValues(finalList, globalIndex);
      } else {
        setValues(
          finalList,
          globalIndex,
          recommend: recommend,
          playlistBox: playlistBox,
        );
      }
    }
  }

  static Future<MediaItem> setTags(
    SongModel response,
    Directory tempDir,
  ) async {
    var playTitle = response.title;
    playTitle == ''
        ? playTitle = response.displayNameWOExt
        : playTitle = response.title;
    var playArtist = response.artist!;
    playArtist == '<unknown>'
        ? playArtist = 'Unknown'
        : playArtist = response.artist!;

    final playAlbum = response.album!;
    final playDuration = response.duration ?? 180000;
    final imagePath = '${tempDir.path}/${response.displayNameWOExt}.jpg';

    final tempDict = MediaItem(
      id: response.id.toString(),
      album: playAlbum,
      duration: Duration(milliseconds: playDuration),
      title: playTitle.split('(')[0],
      artist: playArtist,
      genre: response.genre,
      artUri: Uri.file(imagePath),
      extras: {
        'url': response.data,
        'date_added': response.dateAdded,
        'date_modified': response.dateModified,
        'size': response.size,
        'year': response.getMap['year'],
      },
    );
    return tempDict;
  }

  static void setOffDesktopValues(List response, int index) {
    getTemporaryDirectory().then((tempDir) async {
      final file = File('${tempDir.path}/cover.jpg');
      if (!await file.exists()) {
        final byteData = await rootBundle.load('assets/cover.jpg');
        await file.writeAsBytes(
          byteData.buffer
              .asUint8List(byteData.offsetInBytes, byteData.lengthInBytes),
        );
      }
      final queue = <MediaItem>[];
      queue.addAll(
        response.map(
          (song) => MediaItem(
            id: song['id'].toString(),
            album: song['album'].toString(),
            artist: song['artist'].toString(),
            duration: Duration(
              seconds: int.parse(
                (song['duration'] == null || song['duration'] == 'null')
                    ? '180'
                    : song['duration'].toString(),
              ),
            ),
            title: song['title'].toString(),
            artUri: Uri.file(file.path),
            genre: song['genre'].toString(),
            extras: {
              'url': song['path'].toString(),
              'subtitle': song['subtitle'],
              'quality': song['quality'],
            },
          ),
        ),
      );
      unawaited(updateNplay(queue, index));
    });
  }

  static void setOffValues(List response, int index) {
    getTemporaryDirectory().then((tempDir) async {
      final file = File('${tempDir.path}/cover.jpg');
      if (!await file.exists()) {
        final byteData = await rootBundle.load('assets/cover.jpg');
        await file.writeAsBytes(
          byteData.buffer
              .asUint8List(byteData.offsetInBytes, byteData.lengthInBytes),
        );
      }
      final queue = <MediaItem>[];
      for (var i = 0; i < response.length; i++) {
        queue.add(
          await setTags(response[i] as SongModel, tempDir),
        );
      }
      unawaited(updateNplay(queue, index));
    });
  }

  static void setDownValues(List response, int index) {
    final queue = <MediaItem>[];
    queue.addAll(
      response.map(
        (song) => MediaItemConverter.downMapToMediaItem(song as Map),
      ),
    );
    updateNplay(queue, index);
  }

  static void setValues(
    List response,
    int index, {
    bool recommend = true,
    String? playlistBox,
  }) {
    final queue = <MediaItem>[];
    queue.addAll(
      response.map(
        (song) => MediaItemConverter.mapToMediaItem(
          song as Map,
          autoplay: recommend,
          playlistBox: playlistBox,
        ),
      ),
    );
    updateNplay(queue, index);
  }

  static Future<void> updateNplay(List<MediaItem> queue, int index) async {
    await audioHandler.setShuffleMode(AudioServiceShuffleMode.none);
    await audioHandler.updateQueue(queue);
    await audioHandler.skipToQueueItem(index);
    await audioHandler.play();
    final repeatMode =
        Hive.box('settings').get('repeatMode', defaultValue: 'None').toString();
    final enforceRepeat =
        Hive.box('settings').get('enforceRepeat', defaultValue: false) as bool;
    if (enforceRepeat) {
      switch (repeatMode) {
        case 'None':
          await audioHandler.setRepeatMode(AudioServiceRepeatMode.none);
          break;
        case 'All':
          await audioHandler.setRepeatMode(AudioServiceRepeatMode.all);
          break;
        case 'One':
          await audioHandler.setRepeatMode(AudioServiceRepeatMode.one);
          break;
        default:
          break;
      }
    } else {
      await audioHandler.setRepeatMode(AudioServiceRepeatMode.none);
      await Hive.box('settings').put('repeatMode', 'None');
    }
  }
}
