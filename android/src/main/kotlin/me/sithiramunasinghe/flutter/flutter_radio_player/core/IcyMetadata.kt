package me.sithiramunasinghe.flutter.flutter_radio_player.core

import java.util.regex.Matcher

class IcyMetadata(content: String) {
    private val map: MutableMap<String, String> = mutableMapOf<String, String>()

    init {
        parse(content)
    }

    private fun parse(content: String) {
        val matches = Regex(pattern = "(?<key>[\\w.]*)=\\\"(?<value>[^\"]*)\\\"").findAll(content)
        matches.forEach {
            val (key, value) = it.destructured;
            map[key] = value
        }
    }

    public fun get(key: String): String? {
        return map[key];
    }

    public fun getMap(): Map<String, String> { return map }
}