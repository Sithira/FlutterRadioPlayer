package me.sithiramunasinghe.flutter.flutter_radio_player.core.logic

import me.sithiramunasinghe.flutter.flutter_radio_player.core.api.PlaybackStatus
import org.json.JSONArray
import org.json.JSONObject
import org.junit.jupiter.api.DynamicTest
import org.junit.jupiter.api.DynamicTest.dynamicTest
import org.junit.jupiter.api.TestFactory
import kotlin.test.assertEquals

private class Source(val id: String, val url: String, val headers: Map<String, String>)

private fun cases(file: String): List<JSONObject> {
    val text = SharedTablesTest::class.java.classLoader!!.getResource(file)!!.readText()
    val array = JSONObject(text).getJSONArray("cases")
    return (0 until array.length()).map(array::getJSONObject)
}

private fun sources(array: JSONArray): List<Source> = (0 until array.length()).map {
    val json = array.getJSONObject(it)
    val url = json.getString("url")
    val headers = json.optJSONObject("headers")
        ?.let { h -> h.keys().asSequence().associateWith(h::getString) }
        .orEmpty()
    Source(json.optString("id", url), url, headers)
}

private fun JSONObject.intOrNull(key: String): Int? = if (isNull(key)) null else getInt(key)

class SharedTablesTest {
    @TestFactory
    fun selectionCases(): List<DynamicTest> = cases("selection_cases.json").map { case ->
        dynamicTest(case.getString("name")) {
            val selection = selectSource(
                old = sources(case.getJSONArray("old")),
                oldIndex = case.intOrNull("oldIndex"),
                new = sources(case.getJSONArray("new")),
                initialIndex = case.intOrNull("initialIndex"),
                id = Source::id,
                sameStream = { a, b -> a.id == b.id && a.url == b.url && a.headers == b.headers },
            )
            assertEquals(case.intOrNull("expectedIndex"), selection.index)
            assertEquals(case.getString("expectedStream") == "keep", selection.keepStream)
        }
    }

    @TestFactory
    fun urlCases(): List<DynamicTest> = cases("url_cases.json").map { case ->
        val input = case.getString("input")
        dynamicTest("\"$input\"") {
            assertEquals(case.getBoolean("valid"), isPlayableUrl(input))
        }
    }

    @TestFactory
    fun statusCases(): List<DynamicTest> = cases("status_cases.json").map { case ->
        dynamicTest(case.getString("name")) {
            val inputs = case.getJSONObject("inputs")
            val facts = PlayerFacts(
                hasSources = inputs.getBoolean("hasSources"),
                reconnectPending = inputs.getBoolean("reconnectPending"),
                failed = inputs.getBoolean("failed"),
                playRequested = inputs.getBoolean("playRequested"),
                rendering = inputs.getBoolean("rendering"),
            )
            assertEquals(PlaybackStatus.valueOf(case.getString("expected").uppercase()), statusOf(facts))
        }
    }
}
