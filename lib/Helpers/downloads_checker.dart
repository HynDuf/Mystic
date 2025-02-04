/*
 *  This file is part of Mystic (https://github.com/Sangwan5688/Mystic).
 * 
 * Mystic is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * Mystic is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with Mystic.  If not, see <http://www.gnu.org/licenses/>.
 * 
 * Copyright (c) 2021-2022, Ankit Sangwan
 */

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

Future<void> downloadChecker() async {
  final List songs = Hive.box('downloads').values.toList();
  final List<String> keys = await compute(checkPaths, songs);
  await Hive.box('downloads').deleteAll(keys);
}

Future<List<String>> checkPaths(List songs) async {
  final List<String> res = [];
  for (final song in songs) {
    final bool value = await File(song['path'].toString()).exists();
    if (!value) res.add(song['id'].toString());
  }
  return res;
}
