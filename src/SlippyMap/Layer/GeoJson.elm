module SlippyMap.Layer.GeoJson
    exposing
        ( Config
        , defaultConfig
        , layer
        )

{-| A layer to render GeoJson.

@docs Config, defaultConfig, layer

-}

import GeoJson exposing (GeoJson)
import SlippyMap.Geo.Transform as Transform exposing (Transform)
import SlippyMap.Layer.GeoJson.Render as Render
import SlippyMap.Layer.LowLevel as Layer exposing (Layer)
import Svg exposing (Svg)
import Svg.Attributes


-- CONFIG


{-| Configuration for the layer.
-}
type Config msg
    = Config
        { style : GeoJson.FeatureObject -> List (Svg.Attribute msg)
        }


{-| -}
defaultConfig : Config msg
defaultConfig =
    Config
        { style =
            always
                [ Svg.Attributes.stroke "#3388ff"
                , Svg.Attributes.strokeWidth "3"
                , Svg.Attributes.fill "#3388ff"
                , Svg.Attributes.fillOpacity "0.2"
                , Svg.Attributes.strokeLinecap "round"
                , Svg.Attributes.strokeLinejoin "round"
                ]
        }



-- LAYER


{-| -}
layer : Config msg -> GeoJson -> Layer msg
layer config geoJson =
    Layer.withRender Layer.overlay (render config geoJson)


render : Config msg -> GeoJson -> Layer.RenderState -> Svg msg
render (Config internalConfig) geoJson ({ locationToContainerPoint } as renderstate) =
    let
        centerPoint =
            renderstate.centerPoint

        project ( lon, lat, _ ) =
            locationToContainerPoint { lon = lon, lat = lat }

        renderConfig =
            Render.Config
                { project = project
                , style = internalConfig.style
                }
    in
    Svg.g []
        [ Render.renderGeoJson renderConfig geoJson ]
