package com.tecladus.trainer.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.unit.dp
import com.tecladus.trainer.R

/**
 * Cada alimento tiene su ilustración. Se resuelve por id y, si es un alimento cargado
 * por el usuario, por palabras del nombre: así una comida propia también entra con imagen.
 */
object FoodIcons {

    private val byId = mapOf(
        "huevo" to R.drawable.food_egg,
        "clara" to R.drawable.food_egg,
        "agua" to R.drawable.food_water,
        "agua_saborizada" to R.drawable.food_water,
        "banana" to R.drawable.food_banana,
        "manzana" to R.drawable.food_apple,
        "pera" to R.drawable.food_apple,
        "durazno" to R.drawable.food_apple,
        "naranja" to R.drawable.food_apple,
        "mandarina" to R.drawable.food_apple,
        "uva" to R.drawable.food_apple,
        "frutilla" to R.drawable.food_apple,
        "datiles" to R.drawable.food_nuts,
        "pasas" to R.drawable.food_nuts,
        "palta" to R.drawable.food_vegetable,
        "arroz_blanco" to R.drawable.food_rice,
        "arroz_integral" to R.drawable.food_rice,
        "fideos" to R.drawable.food_pasta,
        "polenta" to R.drawable.food_rice,
        "avena" to R.drawable.food_rice,
        "cereal_azucarado" to R.drawable.food_rice,
        "pan_frances" to R.drawable.food_bread,
        "pan_integral" to R.drawable.food_bread,
        "galletas_arroz" to R.drawable.food_bread,
        "medialuna" to R.drawable.food_bread,
        "papa" to R.drawable.food_potato,
        "batata" to R.drawable.food_potato,
        "pizza_muzza" to R.drawable.food_pizza,
        "empanada_carne" to R.drawable.food_empanada,
        "tarta_verdura" to R.drawable.food_empanada,
        "nalga" to R.drawable.food_meat,
        "bife_chorizo" to R.drawable.food_meat,
        "milanesa_carne" to R.drawable.food_meat,
        "cerdo_lomo" to R.drawable.food_meat,
        "pollo_pechuga" to R.drawable.food_chicken,
        "pollo_muslo" to R.drawable.food_chicken,
        "merluza" to R.drawable.food_fish,
        "atun_lata" to R.drawable.food_fish,
        "leche_entera" to R.drawable.food_milk,
        "leche_descremada" to R.drawable.food_milk,
        "yogur_natural" to R.drawable.food_yogurt,
        "yogur_descremado" to R.drawable.food_yogurt,
        "ricota" to R.drawable.food_cheese,
        "queso_port_salut" to R.drawable.food_cheese,
        "queso_cremoso" to R.drawable.food_cheese,
        "queso_rallado" to R.drawable.food_cheese,
        "dulce_leche" to R.drawable.food_sweet,
        "miel" to R.drawable.food_sweet,
        "azucar" to R.drawable.food_sweet,
        "chocolate_70" to R.drawable.food_chocolate,
        "alfajor_simple" to R.drawable.food_chocolate,
        "barra_cereal" to R.drawable.food_bar,
        "lentejas" to R.drawable.food_legume,
        "garbanzos" to R.drawable.food_legume,
        "porotos" to R.drawable.food_legume,
        "arvejas" to R.drawable.food_legume,
        "soja_texturizada" to R.drawable.food_legume,
        "almendras" to R.drawable.food_nuts,
        "nueces" to R.drawable.food_nuts,
        "mani" to R.drawable.food_nuts,
        "semillas_chia" to R.drawable.food_nuts,
        "mantequilla_mani" to R.drawable.food_nuts,
        "aceite_oliva" to R.drawable.food_oil,
        "lechuga" to R.drawable.food_vegetable,
        "tomate" to R.drawable.food_vegetable,
        "zanahoria" to R.drawable.food_vegetable,
        "zapallo" to R.drawable.food_vegetable,
        "brocoli" to R.drawable.food_vegetable,
        "espinaca" to R.drawable.food_vegetable,
        "cebolla" to R.drawable.food_vegetable,
        "choclo" to R.drawable.food_vegetable,
        "cafe" to R.drawable.food_coffee,
        "mate_cocido" to R.drawable.food_coffee,
        "jugo_naranja" to R.drawable.food_drink,
        "gaseosa_cola" to R.drawable.food_soda,
        "cerveza" to R.drawable.food_soda,
        "gel_deportivo" to R.drawable.food_gel,
        "gel_cafeina" to R.drawable.food_gel,
        "gomitas_energia" to R.drawable.food_gel,
        "banana_gel_casero" to R.drawable.food_gel,
        "bebida_isotonica" to R.drawable.food_drink,
        "bebida_cho_electro" to R.drawable.food_powder,
        "proteina_whey" to R.drawable.food_powder,
        "recuperador" to R.drawable.food_powder,
        "sales_capsula" to R.drawable.food_salt,
        "barrita_energetica" to R.drawable.food_bar
    )

    private val byKeyword = listOf(
        listOf("huevo", "clara") to R.drawable.food_egg,
        listOf("agua", "hidrat") to R.drawable.food_water,
        listOf("banana", "plátano", "platano") to R.drawable.food_banana,
        listOf("manzana", "pera", "fruta", "naranja", "durazno", "uva", "frutilla") to R.drawable.food_apple,
        listOf("arroz", "avena", "cereal", "polenta", "quinoa") to R.drawable.food_rice,
        listOf("fideo", "pasta", "ñoqui", "noqui", "tallarin") to R.drawable.food_pasta,
        listOf("pan", "tostada", "galleta", "factura", "medialuna") to R.drawable.food_bread,
        listOf("papa", "batata", "puré", "pure") to R.drawable.food_potato,
        listOf("pizza") to R.drawable.food_pizza,
        listOf("empanada", "tarta") to R.drawable.food_empanada,
        listOf("carne", "bife", "asado", "milanesa", "cerdo", "vacío", "vacio") to R.drawable.food_meat,
        listOf("pollo", "pechuga", "pavo") to R.drawable.food_chicken,
        listOf("pescado", "merluza", "atún", "atun", "salmón", "salmon") to R.drawable.food_fish,
        listOf("leche", "licuado") to R.drawable.food_milk,
        listOf("yogur", "yoghurt") to R.drawable.food_yogurt,
        listOf("queso", "ricota") to R.drawable.food_cheese,
        listOf("verdura", "ensalada", "lechuga", "tomate", "brócoli", "brocoli", "espinaca", "zapallo", "zanahoria") to R.drawable.food_vegetable,
        listOf("lenteja", "garbanzo", "poroto", "arveja", "soja", "legumbre") to R.drawable.food_legume,
        listOf("almendra", "nuez", "nueces", "maní", "mani", "semilla", "fruto seco") to R.drawable.food_nuts,
        listOf("aceite", "manteca", "mantequilla") to R.drawable.food_oil,
        listOf("café", "cafe", "mate", "té", "te ") to R.drawable.food_coffee,
        listOf("jugo", "bebida", "isotónica", "isotonica", "licuado") to R.drawable.food_drink,
        listOf("gaseosa", "cola", "cerveza", "lata") to R.drawable.food_soda,
        listOf("dulce", "azúcar", "azucar", "miel", "mermelada") to R.drawable.food_sweet,
        listOf("chocolate", "alfajor", "galletita") to R.drawable.food_chocolate,
        listOf("barra", "barrita") to R.drawable.food_bar,
        listOf("gel", "gomita") to R.drawable.food_gel,
        listOf("sal", "electrolito", "sales") to R.drawable.food_salt,
        listOf("proteína", "proteina", "whey", "polvo", "recuperador") to R.drawable.food_powder
    )

    fun forFood(id: String, name: String = ""): Int {
        byId[id]?.let { return it }
        val haystack = "${id.lowercase()} ${name.lowercase()}"
        byKeyword.forEach { (keywords, res) ->
            if (keywords.any { haystack.contains(it) }) return res
        }
        return R.drawable.food_generic
    }
}

/** Miniatura del alimento: ilustración sobre una superficie redondeada. */
@Composable
fun FoodAvatar(
    foodId: String,
    name: String,
    modifier: Modifier = Modifier,
    size: Int = 42
) {
    Box(
        modifier = modifier
            .size(size.dp)
            .clip(RoundedCornerShape((size / 3).dp))
            .background(MaterialTheme.colorScheme.background),
        contentAlignment = Alignment.Center
    ) {
        androidx.compose.foundation.Image(
            painter = painterResource(id = FoodIcons.forFood(foodId, name)),
            contentDescription = null,
            modifier = Modifier.size((size * 0.62f).dp)
        )
    }
}
