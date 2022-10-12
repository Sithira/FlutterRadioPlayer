class FRPSource {
  List<MediaSources>? _mediaSources;

  FRPSource({required List<MediaSources> mediaSources}) {
    _mediaSources = mediaSources;
  }

  FRPSource.fromJson(Map<String, dynamic> json) {
    if (json['media_sources'] != null) {
      _mediaSources = <MediaSources>[];
      json['media_sources'].forEach((v) {
        _mediaSources!.add(MediaSources.fromJson(v));
      });
    }
  }

  List<MediaSources>? get mediaSources => _mediaSources;

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (_mediaSources != null) {
      data['media_sources'] = _mediaSources!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class MediaSources {
  String? url;
  String? title;
  bool isPrimary = false;
  String? description;
  bool? isAac;

  MediaSources({
    String? url,
    String? title,
    required this.isPrimary,
    String? description,
    bool? isAac,
  }) {
    if (url != null) {
      this.url = url;
    }
    if (title != null) {
      this.title = title;
    }

    if (description != null) {
      this.description = description;
    }
    if (isAac != null) {
      this.isAac = isAac;
    }
  }

  MediaSources.fromJson(Map<String, dynamic> json) {
    url = json['url'];
    title = json['title'];
    isPrimary = json['isPrimary'];
    description = json['description'];
    isAac = json[''];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['url'] = url;
    data['title'] = title;
    data['isPrimary'] = isPrimary;
    data['description'] = description;
    data['isAac'] = isAac;
    return data;
  }
}
