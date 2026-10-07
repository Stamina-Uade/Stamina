package com.tecladus.trainer.data.catalog

import com.tecladus.trainer.domain.model.Food

/**
 * Base de alimentos embebida (valores por 100 g de porción comestible).
 *
 * Está armada con productos habituales en Argentina y con la categoría específica
 * de "nutrición deportiva", que es la que se usa durante el esfuerzo.
 * Los valores son de referencia; el usuario puede cargar alimentos propios.
 */
object FoodCatalog {

    private fun f(
        id: String, name: String, cat: String,
        kcal: Double, p: Double, c: Double, g: Double, na: Double,
        portion: Double, portionLabel: String
    ) = Food(id, name, cat, kcal, p, c, g, na, portion, portionLabel)

    val CEREALS = "Cereales y panificados"
    val FRUITS = "Frutas"
    val VEGETABLES = "Verduras"
    val MEATS = "Carnes y huevos"
    val DAIRY = "Lácteos"
    val LEGUMES = "Legumbres"
    val NUTS = "Frutos secos y semillas"
    val DRINKS = "Bebidas"
    val SPORTS = "Nutrición deportiva"
    val OTHERS = "Otros"

    val foods: List<Food> = listOf(
        // -------------------------------------------------- cereales y panificados
        f("arroz_blanco", "Arroz blanco cocido", CEREALS, 130.0, 2.7, 28.0, 0.3, 1.0, 200.0, "1 plato (200 g)"),
        f("arroz_integral", "Arroz integral cocido", CEREALS, 123.0, 2.6, 25.6, 1.0, 4.0, 200.0, "1 plato (200 g)"),
        f("fideos", "Fideos secos cocidos", CEREALS, 158.0, 5.8, 30.9, 0.9, 5.0, 250.0, "1 plato (250 g)"),
        f("polenta", "Polenta cocida", CEREALS, 85.0, 2.0, 18.0, 0.4, 3.0, 250.0, "1 porción (250 g)"),
        f("pan_frances", "Pan francés", CEREALS, 277.0, 8.9, 55.0, 2.5, 540.0, 60.0, "1 mignon (60 g)"),
        f("pan_integral", "Pan integral", CEREALS, 247.0, 10.0, 41.0, 3.4, 450.0, 50.0, "2 rebanadas (50 g)"),
        f("galletas_arroz", "Galletas de arroz", CEREALS, 387.0, 8.0, 81.0, 3.0, 30.0, 20.0, "3 unidades (20 g)"),
        f("avena", "Avena arrollada", CEREALS, 389.0, 16.9, 66.3, 6.9, 2.0, 40.0, "4 cdas (40 g)"),
        f("cereal_azucarado", "Copos de maíz azucarados", CEREALS, 380.0, 6.0, 85.0, 1.0, 500.0, 30.0, "1 taza (30 g)"),
        f("papa", "Papa hervida", VEGETABLES, 87.0, 2.0, 20.0, 0.1, 5.0, 200.0, "2 medianas (200 g)"),
        f("batata", "Batata hervida", VEGETABLES, 90.0, 2.0, 20.7, 0.2, 36.0, 200.0, "1 mediana (200 g)"),
        f("tarta_verdura", "Tarta de verdura (porción)", OTHERS, 210.0, 7.0, 22.0, 10.0, 380.0, 150.0, "1 porción (150 g)"),
        f("empanada_carne", "Empanada de carne al horno", OTHERS, 260.0, 10.0, 26.0, 12.0, 420.0, 100.0, "1 unidad (100 g)"),
        f("pizza_muzza", "Pizza de muzzarella", OTHERS, 266.0, 11.0, 33.0, 10.0, 600.0, 120.0, "1 porción (120 g)"),
        f("medialuna", "Medialuna de manteca", CEREALS, 420.0, 7.0, 50.0, 21.0, 350.0, 45.0, "1 unidad (45 g)"),

        // ------------------------------------------------------------------ frutas
        f("banana", "Banana", FRUITS, 89.0, 1.1, 22.8, 0.3, 1.0, 120.0, "1 mediana (120 g)"),
        f("manzana", "Manzana", FRUITS, 52.0, 0.3, 13.8, 0.2, 1.0, 150.0, "1 mediana (150 g)"),
        f("naranja", "Naranja", FRUITS, 47.0, 0.9, 11.8, 0.1, 0.0, 180.0, "1 mediana (180 g)"),
        f("pera", "Pera", FRUITS, 57.0, 0.4, 15.2, 0.1, 1.0, 170.0, "1 mediana (170 g)"),
        f("uva", "Uva", FRUITS, 69.0, 0.7, 18.1, 0.2, 2.0, 100.0, "1 taza (100 g)"),
        f("frutilla", "Frutillas", FRUITS, 32.0, 0.7, 7.7, 0.3, 1.0, 150.0, "1 taza (150 g)"),
        f("mandarina", "Mandarina", FRUITS, 53.0, 0.8, 13.3, 0.3, 2.0, 120.0, "1 unidad (120 g)"),
        f("durazno", "Durazno", FRUITS, 39.0, 0.9, 9.5, 0.3, 0.0, 150.0, "1 unidad (150 g)"),
        f("datiles", "Dátiles", FRUITS, 282.0, 2.5, 75.0, 0.4, 2.0, 40.0, "5 unidades (40 g)"),
        f("pasas", "Pasas de uva", FRUITS, 299.0, 3.1, 79.2, 0.5, 11.0, 30.0, "1 puñado (30 g)"),

        // ---------------------------------------------------------------- verduras
        f("lechuga", "Lechuga", VEGETABLES, 15.0, 1.4, 2.9, 0.2, 28.0, 60.0, "1 plato (60 g)"),
        f("tomate", "Tomate", VEGETABLES, 18.0, 0.9, 3.9, 0.2, 5.0, 150.0, "1 mediano (150 g)"),
        f("zanahoria", "Zanahoria", VEGETABLES, 41.0, 0.9, 9.6, 0.2, 69.0, 80.0, "1 unidad (80 g)"),
        f("zapallo", "Zapallo", VEGETABLES, 26.0, 1.0, 6.5, 0.1, 1.0, 200.0, "1 porción (200 g)"),
        f("brocoli", "Brócoli", VEGETABLES, 34.0, 2.8, 6.6, 0.4, 33.0, 150.0, "1 porción (150 g)"),
        f("espinaca", "Espinaca", VEGETABLES, 23.0, 2.9, 3.6, 0.4, 79.0, 100.0, "1 porción (100 g)"),
        f("cebolla", "Cebolla", VEGETABLES, 40.0, 1.1, 9.3, 0.1, 4.0, 80.0, "1 unidad (80 g)"),
        f("choclo", "Choclo", VEGETABLES, 96.0, 3.4, 21.0, 1.5, 15.0, 150.0, "1 unidad (150 g)"),

        // ------------------------------------------------------------------ carnes
        f("nalga", "Carne vacuna magra (nalga)", MEATS, 143.0, 21.8, 0.0, 5.9, 55.0, 150.0, "1 bife (150 g)"),
        f("bife_chorizo", "Bife de chorizo", MEATS, 250.0, 20.0, 0.0, 19.0, 60.0, 200.0, "1 bife (200 g)"),
        f("pollo_pechuga", "Pechuga de pollo", MEATS, 165.0, 31.0, 0.0, 3.6, 74.0, 150.0, "1 pechuga (150 g)"),
        f("pollo_muslo", "Muslo de pollo sin piel", MEATS, 179.0, 24.0, 0.0, 8.7, 86.0, 130.0, "1 muslo (130 g)"),
        f("merluza", "Merluza", MEATS, 90.0, 18.0, 0.0, 1.8, 90.0, 150.0, "1 filet (150 g)"),
        f("atun_lata", "Atún al natural (lata)", MEATS, 116.0, 26.0, 0.0, 1.0, 320.0, 120.0, "1 lata (120 g)"),
        f("huevo", "Huevo entero", MEATS, 155.0, 13.0, 1.1, 11.0, 124.0, 55.0, "1 unidad (55 g)"),
        f("clara", "Clara de huevo", MEATS, 52.0, 11.0, 0.7, 0.2, 166.0, 33.0, "1 clara (33 g)"),
        f("cerdo_lomo", "Lomo de cerdo", MEATS, 143.0, 21.0, 0.0, 6.0, 62.0, 150.0, "1 porción (150 g)"),
        f("milanesa_carne", "Milanesa de carne al horno", MEATS, 215.0, 19.0, 12.0, 10.0, 350.0, 130.0, "1 unidad (130 g)"),

        // ----------------------------------------------------------------- lácteos
        f("leche_entera", "Leche entera", DAIRY, 61.0, 3.2, 4.8, 3.3, 43.0, 250.0, "1 taza (250 ml)"),
        f("leche_descremada", "Leche descremada", DAIRY, 35.0, 3.4, 5.0, 0.1, 44.0, 250.0, "1 taza (250 ml)"),
        f("yogur_natural", "Yogur natural", DAIRY, 61.0, 3.5, 4.7, 3.3, 46.0, 190.0, "1 pote (190 g)"),
        f("yogur_descremado", "Yogur descremado con frutas", DAIRY, 78.0, 4.0, 13.0, 0.9, 50.0, 190.0, "1 pote (190 g)"),
        f("queso_port_salut", "Queso port salut", DAIRY, 320.0, 20.0, 2.0, 26.0, 700.0, 30.0, "1 feta (30 g)"),
        f("queso_cremoso", "Queso cremoso", DAIRY, 300.0, 18.0, 2.5, 24.0, 650.0, 30.0, "1 feta (30 g)"),
        f("ricota", "Ricota descremada", DAIRY, 138.0, 11.0, 3.0, 8.0, 130.0, 100.0, "1 porción (100 g)"),
        f("queso_rallado", "Queso rallado", DAIRY, 392.0, 33.0, 3.0, 28.0, 1400.0, 15.0, "2 cdas (15 g)"),
        f("dulce_leche", "Dulce de leche", DAIRY, 315.0, 6.0, 55.0, 7.0, 130.0, 30.0, "2 cdas (30 g)"),

        // --------------------------------------------------------------- legumbres
        f("lentejas", "Lentejas cocidas", LEGUMES, 116.0, 9.0, 20.0, 0.4, 2.0, 200.0, "1 plato (200 g)"),
        f("garbanzos", "Garbanzos cocidos", LEGUMES, 164.0, 8.9, 27.4, 2.6, 7.0, 200.0, "1 plato (200 g)"),
        f("porotos", "Porotos negros cocidos", LEGUMES, 132.0, 8.9, 23.7, 0.5, 2.0, 200.0, "1 plato (200 g)"),
        f("arvejas", "Arvejas", LEGUMES, 81.0, 5.4, 14.5, 0.4, 5.0, 150.0, "1 porción (150 g)"),
        f("soja_texturizada", "Soja texturizada (seca)", LEGUMES, 330.0, 50.0, 30.0, 1.0, 20.0, 30.0, "1 porción (30 g)"),

        // ------------------------------------------------------ frutos secos y otros
        f("almendras", "Almendras", NUTS, 579.0, 21.0, 21.6, 49.9, 1.0, 30.0, "1 puñado (30 g)"),
        f("nueces", "Nueces", NUTS, 654.0, 15.2, 13.7, 65.2, 2.0, 30.0, "1 puñado (30 g)"),
        f("mani", "Maní tostado", NUTS, 567.0, 25.8, 16.1, 49.2, 6.0, 30.0, "1 puñado (30 g)"),
        f("semillas_chia", "Semillas de chía", NUTS, 486.0, 16.5, 42.1, 30.7, 16.0, 15.0, "1 cda (15 g)"),
        f("mantequilla_mani", "Pasta de maní", NUTS, 588.0, 25.0, 20.0, 50.0, 350.0, 20.0, "1 cda (20 g)"),
        f("aceite_oliva", "Aceite de oliva", OTHERS, 884.0, 0.0, 0.0, 100.0, 2.0, 10.0, "1 cda (10 g)"),
        f("palta", "Palta", FRUITS, 160.0, 2.0, 8.5, 14.7, 7.0, 100.0, "1/2 unidad (100 g)"),
        f("miel", "Miel", OTHERS, 304.0, 0.3, 82.4, 0.0, 4.0, 20.0, "1 cda (20 g)"),
        f("azucar", "Azúcar", OTHERS, 387.0, 0.0, 100.0, 0.0, 1.0, 10.0, "1 cdita (10 g)"),
        f("chocolate_70", "Chocolate 70% cacao", OTHERS, 598.0, 7.8, 45.9, 42.6, 20.0, 25.0, "2 cuadraditos (25 g)"),
        f("alfajor_simple", "Alfajor simple", OTHERS, 420.0, 4.0, 62.0, 17.0, 220.0, 45.0, "1 unidad (45 g)"),
        f("barra_cereal", "Barra de cereal", OTHERS, 380.0, 6.0, 68.0, 9.0, 190.0, 25.0, "1 unidad (25 g)"),

        // ---------------------------------------------------------------- bebidas
        f("agua", "Agua", DRINKS, 0.0, 0.0, 0.0, 0.0, 2.0, 500.0, "1 botella (500 ml)"),
        f("agua_saborizada", "Agua saborizada", DRINKS, 20.0, 0.0, 5.0, 0.0, 10.0, 500.0, "1 botella (500 ml)"),
        f("gaseosa_cola", "Gaseosa cola", DRINKS, 42.0, 0.0, 10.6, 0.0, 4.0, 350.0, "1 lata (350 ml)"),
        f("jugo_naranja", "Jugo de naranja exprimido", DRINKS, 45.0, 0.7, 10.4, 0.2, 1.0, 250.0, "1 vaso (250 ml)"),
        f("mate_cocido", "Mate cocido sin azúcar", DRINKS, 2.0, 0.0, 0.3, 0.0, 2.0, 250.0, "1 taza (250 ml)"),
        f("cafe", "Café solo", DRINKS, 2.0, 0.1, 0.0, 0.0, 2.0, 200.0, "1 taza (200 ml)"),
        f("cerveza", "Cerveza rubia", DRINKS, 43.0, 0.5, 3.6, 0.0, 4.0, 350.0, "1 vaso (350 ml)"),

        // ------------------------------------------------------ nutrición deportiva
        f("gel_deportivo", "Gel deportivo (25 g CHO)", SPORTS, 250.0, 0.0, 62.5, 0.0, 200.0, 40.0, "1 sobre (40 g)"),
        f("gel_cafeina", "Gel con cafeína", SPORTS, 250.0, 0.0, 60.0, 0.0, 250.0, 40.0, "1 sobre (40 g)"),
        f("bebida_isotonica", "Bebida isotónica", SPORTS, 26.0, 0.0, 6.4, 0.0, 41.0, 500.0, "1 botella (500 ml)"),
        f("sales_capsula", "Cápsula de sales (300 mg Na)", SPORTS, 0.0, 0.0, 0.0, 0.0, 30000.0, 1.0, "1 cápsula"),
        f("bebida_cho_electro", "Polvo hidratos + electrolitos", SPORTS, 380.0, 0.0, 94.0, 0.0, 1200.0, 40.0, "1 medida (40 g)"),
        f("barrita_energetica", "Barrita energética deportiva", SPORTS, 360.0, 8.0, 65.0, 7.0, 250.0, 50.0, "1 unidad (50 g)"),
        f("gomitas_energia", "Gomitas energéticas", SPORTS, 330.0, 0.0, 82.0, 0.0, 200.0, 30.0, "1 sobre (30 g)"),
        f("proteina_whey", "Proteína whey en polvo", SPORTS, 400.0, 80.0, 8.0, 5.0, 300.0, 30.0, "1 scoop (30 g)"),
        f("recuperador", "Recuperador post-entreno (CHO+PRO)", SPORTS, 375.0, 25.0, 62.0, 3.0, 400.0, 50.0, "1 medida (50 g)"),
        f("banana_gel_casero", "Gel casero (miel + sal + agua)", SPORTS, 290.0, 0.2, 72.0, 0.0, 900.0, 40.0, "1 porción (40 g)")
    )

    fun search(query: String, extra: List<Food> = emptyList()): List<Food> {
        val all = extra + foods
        if (query.isBlank()) return all.sortedBy { it.name }
        val q = query.trim().lowercase().normalizeAccents()
        return all.filter {
            it.name.lowercase().normalizeAccents().contains(q) ||
                it.category.lowercase().normalizeAccents().contains(q)
        }.sortedBy { it.name }
    }

    fun byId(id: String, extra: List<Food> = emptyList()): Food? =
        extra.firstOrNull { it.id == id } ?: foods.firstOrNull { it.id == id }

    private fun String.normalizeAccents(): String = this
        .replace('á', 'a').replace('é', 'e').replace('í', 'i')
        .replace('ó', 'o').replace('ú', 'u').replace('ü', 'u')
}
