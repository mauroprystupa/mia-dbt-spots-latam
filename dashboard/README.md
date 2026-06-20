# Dashboard MIA — Spots LATAM

Dashboard standalone de análisis publicitario para spots de TV y Radio en Brasil y México.

---

## Cómo usar

1. Colocá el archivo `spot_latam.csv` en la misma carpeta que `dashboard.html`
2. Abrí `dashboard.html` directamente en el browser (Chrome o Edge recomendado)
3. No requiere servidor, instalación ni conexión a internet

Si el CSV no está en la misma carpeta, el dashboard muestra un mensaje de error indicando dónde colocarlo.

---

## Filtros

Los filtros están en la barra superior y se aplican a todos los componentes simultáneamente.

| Filtro | Descripción |
|--------|-------------|
| **Mercado** | Restringe los datos a Brasil, México, o ambos |
| **Medio** | Filtra por tipo de medio: TV Cable, TV Abierta, Radio FM, Radio AM |
| **Segmento** | Filtra por franja horaria de emisión: Primetime, Day o Greytime |
| **Validez** | Válidos muestra solo spots confirmados por el proveedor. Falsos positivos muestra los registros que el proveedor corrigió en la auditoría siguiente. Todos incluye ambos |
| **Duración** | Filtra por duración del aviso en segundos, agrupado en rangos |

El botón **✕ Limpiar** resetea todos los filtros al estado inicial (Válidos activo, resto Todos).

Los gráficos también son interactivos: hacer click sobre una barra, segmento o porción del donut aplica ese valor como filtro. Un segundo click sobre el mismo elemento lo quita.

---

## Métricas — Scorecards

### Total Spots
Cantidad de spots publicitarios emitidos en el período, según los filtros activos. Unidad: spots.

### Inversión Total USD
Suma del costo USD final de todos los spots. Incluye tanto el costo real cuando está disponible como el costo estimado cuando no lo está. Representa la inversión publicitaria total del período.

### Costo Promedio / Spot
Inversión total dividida por la cantidad de spots. Indica cuánto cuesta en promedio cada aviso emitido. Útil para comparar eficiencia entre mercados, medios o franjas horarias.

### Duración Total
Suma de la duración de todos los spots expresada en horas. Mide el volumen de tiempo publicitario emitido.

### Marcas Únicas
Cantidad de marcas comerciales distintas presentes en el período. Indica la diversidad de anunciantes.

### % Costo Estimado
Porcentaje de spots que no tienen costo real registrado y cuyo costo fue imputado por promedio estadístico. Un porcentaje alto indica dependencia en la estimación — el dato debe leerse con precaución para análisis de inversión precisos.

---

## Métricas — Calidad del dato

### Falsos positivos por mercado
Ratio de spots marcados como `is_valid = false` sobre el total de spots del mercado, calculado siempre sobre el universo completo (no se ve afectado por los filtros activos).

Un falso positivo es un spot que apareció en el archivo de auditoría del día 1 pero que el proveedor eliminó en el archivo del día 2, indicando que fue un error de reporte. Mide la calidad del dato entregado por el proveedor para cada mercado.

---

## Métricas — Gráficos

### Inversión por Mercado y Segmento
Barras apiladas que muestran la inversión total en USD por mercado (Brasil / México), desglosada por franja horaria (Primetime, Day, Greytime). Permite ver cómo se distribuye el gasto publicitario entre mercados y en qué franja se concentra.

### Distribución por Medio
Donut que muestra qué proporción del total de spots corresponde a cada tipo de medio (TV Cable, TV Abierta, Radio FM, Radio AM). Refleja el mix de inventario utilizado.

### Mix de Duración
Donut que agrupa los spots según la duración del aviso en rangos de 15 segundos. Indica el formato predominante de la pauta: avisos cortos (0–15s), estándar (16–30s) o extendidos.

### Volumen de Spots por Día
Barras agrupadas que muestran la cantidad de spots emitidos por fecha, con una barra para Brasil y otra para México. Permite identificar picos de actividad, días sin emisión y diferencias de cadencia entre mercados.

### Top 10 Marcas
Ranking de las 10 marcas comerciales con mayor inversión acumulada en USD. Muestra quién lidera el gasto publicitario en el período.

### Top 10 Canales
Ranking de los 10 canales con mayor cantidad de spots emitidos. Indica dónde se concentra el volumen de pauta, independientemente del costo.

### Top 10 Sectores
Ranking de los 10 sectores de negocio con mayor inversión acumulada en USD. Muestra qué industrias son las principales compradoras de pauta en el período.

### Inversión Real vs Estimada
Barras apiladas por mercado que separan la inversión con costo real disponible (color sólido) de la inversión con costo imputado estadísticamente (color claro). El porcentaje indicado debajo de cada barra muestra qué proporción del total de ese mercado es estimada. Brasil tiene costo real en la mayoría de los spots; México no tiene dato de costo real y depende completamente de la estimación.

### Top 10 Grupos de Canal
Ranking de los 10 grupos o redes propietarias de canales con mayor cantidad de spots emitidos. A diferencia del ranking de canales individuales, este agrupa todos los canales de un mismo grupo (por ejemplo, todos los canales ESPN suman como un solo grupo).

### Distribución Horaria de Spots
Mapa de calor que muestra la cantidad de spots por hora del día (0 a 23) para Brasil y México. El color de cada celda indica la franja horaria a la que pertenece esa hora (azul = Primetime, verde = Day, gris = Greytime). La intensidad del color refleja el volumen relativo de spots en esa hora.

---

## Franjas horarias

| Segmento | Horario | Criterio |
|----------|---------|----------|
| **Primetime** | 18:00 – 01:59 | Cruza medianoche — condición OR en lugar de BETWEEN |
| **Day** | 08:00 – 17:59 | Horario diurno estándar |
| **Greytime** | 02:00 – 07:59 | Madrugada — arranca en hora 2, no en hora 0 |

---

## Costo estimado — supuesto importante

México no tiene datos de costo real en la fuente. Todos los costos de México son estimados por promedio estadístico calculado sobre los spots de Brasil con costo real, agrupados por `(mercado, medio, segmento_horario)`.

Esto introduce un sesgo: los costos de México están calibrados con datos de mercado brasileño, que puede tener estructuras de precio distintas. Los valores de inversión para México deben interpretarse como aproximaciones orientativas, no como cifras de facturación reales.
