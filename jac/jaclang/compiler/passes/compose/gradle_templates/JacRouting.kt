package {{package_name}}

object JacRoutes {
    const val initialPath = "{{initial}}"
    val paths = listOf(
{{route_lines}}
    )
    val sections: Map<String, List<String>> = mapOf(
{{section_lines}}
    )
    val deepLinks = listOf(
{{deep_lines}}
    )
}
