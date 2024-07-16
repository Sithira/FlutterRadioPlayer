package me.sithiramunasinghe.flutter.flutter_radio_player.core.data

data class FRPAudioSource(
    val url: String?,
    val isPrimary: Boolean,
    val title: String?,
    val description: String? = null,
    val isAcc: Boolean? = false
) {
    companion object {
        fun fromMap(mediaSource: HashMap<String, Any>): FRPAudioSource {
            return FRPAudioSource(
                mediaSource["url"] as String?,
                mediaSource["isPrimary"] as Boolean,
                mediaSource["title"] as String?,
                mediaSource["description"] as String?,
                mediaSource["isAac"] as Boolean?
            )
        }
    }
}