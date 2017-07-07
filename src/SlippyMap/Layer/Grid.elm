module SlippyMap.Layer.Grid
    exposing
        ( Config
        , defaultConfig
        , layer
        )

{-| A layer to display Lon/Lat grids.

TODO: rename to Graticule

@docs Config, defaultConfig, layer

-}

import Color exposing (Color)
import SlippyMap.Geo.Point as Point exposing (Point)
import SlippyMap.Geo.Transform as Transform exposing (Transform)
import SlippyMap.Layer.LowLevel as Layer exposing (Layer)
import Svg exposing (Svg)
import Svg.Attributes


-- CONFIG


{-| Configuration for the layer.

Note: Your Config should never be held in your model. It should only appear in view code.

-}
type Config
    = Config
        { majorTickColor : Color
        , minorTickColor : Color
        }


{-| -}
defaultConfig : Config
defaultConfig =
    Config
        { majorTickColor = Color.black
        , minorTickColor = Color.grey
        }



-- LAYER


{-| -}
layer : Config -> Layer msg
layer config =
    Layer.withRender Layer.overlay (render config)


render : Config -> Layer.RenderState -> Svg msg
render (Config config) renderState =
    let
        { southWest, northEast } =
            renderState.locationBounds

        lons =
            List.range (floor southWest.lon) (ceiling northEast.lon)
                |> List.map toFloat
                |> List.map
                    (\lon ->
                        ( renderState.locationToContainerPoint
                            { lon = lon, lat = southWest.lat }
                        , renderState.locationToContainerPoint
                            { lon = lon, lat = northEast.lat }
                        )
                    )

        lats =
            List.range (floor southWest.lat) (ceiling northEast.lat)
                |> List.map toFloat
                |> List.map
                    (\lat ->
                        ( renderState.locationToContainerPoint
                            { lon = southWest.lon, lat = lat }
                        , renderState.locationToContainerPoint
                            { lon = northEast.lon, lat = lat }
                        )
                    )
    in
    Svg.g []
        (List.map (line config.majorTickColor) lons
            ++ List.map (line config.majorTickColor) lats
        )


line : Color -> ( Point, Point ) -> Svg msg
line color ( p1, p2 ) =
    Svg.line
        [ Svg.Attributes.x1 (toString p1.x)
        , Svg.Attributes.y1 (toString p1.y)
        , Svg.Attributes.x2 (toString p2.x)
        , Svg.Attributes.y2 (toString p2.y)
        , Svg.Attributes.stroke
            (Color.toRgb color
                |> (\{ red, green, blue, alpha } ->
                        "rgba("
                            ++ toString red
                            ++ ","
                            ++ toString green
                            ++ ","
                            ++ toString blue
                            ++ ","
                            ++ toString alpha
                            ++ ")"
                   )
            )
        , Svg.Attributes.strokeWidth "1"
        , Svg.Attributes.shapeRendering "crispEdges"
        ]
        []
