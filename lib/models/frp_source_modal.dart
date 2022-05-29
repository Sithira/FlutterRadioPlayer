class FRPSource {
  List<MediaSources>? _mediaSources;

  FRPSource({required List<MediaSources> mediaSources}) {
    _mediaSources = mediaSources;
  }

  List<MediaSources>? get mediaSources => _mediaSources;
  set mediaSources(List<MediaSources>? mediaSources) =>
      _mediaSources = mediaSources;

  FRPSource.fromJson(Map<String, dynamic> json) {
    if (json['media_sources'] != null) {
      _mediaSources = <MediaSources>[];
      json['media_sources'].forEach((v) {
        _mediaSources!.add(MediaSources.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (_mediaSources != null) {
      data['media_sources'] =
          _mediaSources!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class MediaSources {
  String? _url;
  String? _title;
  bool? _isPrimary;
  String? _description;
  bool? _isAac;

  MediaSources(
      {String? url, String? title, bool? isPrimary, String? description, bool? isAac}) {
    if (url != null) {
      _url = url;
    }
    if (title != null) {
      _title = title;
    }
    if (isPrimary != null) {
      _isPrimary = isPrimary;
    }
    if (description != null) {
      _description = description;
    }
    if (isAac != null) {
      _isAac = isAac;
    }
  }

  String? get url => _url;
  set url(String? url) => _url = url;
  String? get title => _title;
  set title(String? title) => _title = title;
  bool? get isPrimary => _isPrimary;
  set isPrimary(bool? isPrimary) => _isPrimary = isPrimary;
  String? get description => _description;
  set description(String? description) => _description = description;
  bool? get isAac => _isAac;
  set isAac(bool? isAac) => _isAac = isAac;

  MediaSources.fromJson(Map<String, dynamic> json) {
    _url = json['url'];
    _title = json['title'];
    _isPrimary = json['isPrimary'];
    _description = json['description'];
    _isAac = json[''];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['url'] = _url;
    data['title'] = _title;
    data['isPrimary'] = _isPrimary;
    data['description'] = _description;
    data['isAac'] = _isAac;
    return data;
  }
}
