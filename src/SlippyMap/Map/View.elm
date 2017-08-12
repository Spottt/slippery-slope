module SlippyMap.Map.View exposing (view)

{-|

@docs view

-}

import Html exposing (Html)
import Html.Attributes
import Html.Events
import Json.Decode as Decode exposing (Decoder)
import Mouse exposing (Position)
import SlippyMap.Control.Attribution as Attribution
import SlippyMap.Control.Zoom as Zoom
import SlippyMap.Geo.Point as Point exposing (Point)
import SlippyMap.Layer as Layer exposing (Layer)
import SlippyMap.Map.Config as Config exposing (Config(..))
import SlippyMap.Map.Msg as Msg exposing (DragMsg(..), Msg(..), PinchMsg(..))
import SlippyMap.Map.State as State exposing (State(..))
import SlippyMap.Map.Transform as Transform exposing (Transform)
import SlippyMap.Map.Types as Types exposing (Focus(..))
import Svg exposing (Svg)
import Svg.Attributes


{-| -}
view : Config msg -> State -> List (Layer msg) -> Html msg
view (Config config) ((State { scene, interaction }) as state) nestedLayers =
    let
        transform =
            Transform.transform (Config config) scene

        layers =
            Layer.flatten nestedLayers

        -- TODO: only get attributions from currently visible layers, whatever that means or how it's implemented
        layerAttributions =
            List.concatMap Layer.getAttributions layers

        interactionAttributes =
            case config.toMsg of
                Just toMsg ->
                    List.map
                        (Html.Attributes.map toMsg)
                        (eventAttributes config.interactions)

                Nothing ->
                    []
    in
    Html.div
        ([ Html.Attributes.style
            [ ( "position", "relative" )
            , ( "width", toString config.size.x ++ "px" )
            , ( "height", toString config.size.y ++ "px" )
            , ( "background", "#eee" )
            ]
         , Html.Attributes.classList
            [ ( "with-interaction", interaction /= Types.NoInteraction ) ]
         ]
            ++ interactionAttributes
        )
        [ Html.div
            [ -- This is needed at the moment as a touch event target for panning. The touchmove gets lost when it originates in a tile that gets removed during panning.
              Html.Attributes.style
                [ ( "position"
                  , if interaction /= Types.NoInteraction then
                        "fixed"
                    else
                        "absolute"
                  )
                , ( "left", "0" )
                , ( "top", "0" )
                , ( "right", "0" )
                , ( "bottom", "0" )
                ]
            ]
            []
        , Svg.svg
            [ Svg.Attributes.class "esm__map"

            -- Important for touch pinching
            , Svg.Attributes.pointerEvents "none"
            , Svg.Attributes.height (toString config.size.y)
            , Svg.Attributes.width (toString config.size.x)
            , Svg.Attributes.style "position: absolute;"
            ]
            [ Svg.g
                [ Svg.Attributes.class "esm__layers" ]
                (List.concatMap
                    (viewPane (Config config) transform layers)
                    Layer.panes
                )
            ]
        , Html.div
            [ Html.Attributes.class "esm__controls" ]
            [ Attribution.control config.attributionPrefix
                layerAttributions
            , case config.toMsg of
                Just toMsg ->
                    Html.map toMsg <| Zoom.control transform

                Nothing ->
                    Html.text ""
            ]
        ]


eventAttributes : Config.Interactions -> List (Html.Attribute Msg)
eventAttributes interactions =
    let
        scrollWheelZoom =
            if interactions.scrollWheelZoom then
                [ Html.Events.onWithOptions "wheel"
                    { preventDefault = True
                    , stopPropagation = True
                    }
                    (Decode.map2 (\offset point -> ZoomByAround offset point)
                        (Decode.field "deltaY" Decode.float
                            |> Decode.map (\y -> -y / 100)
                        )
                        clientPosition
                    )
                ]
            else
                []

        doubleClickZoom =
            if interactions.doubleClickZoom then
                [ Html.Events.on "dblclick"
                    (Decode.map ZoomInAround clientPosition)
                ]
            else
                []

        keyboardControl =
            if interactions.keyboardControl then
                [ Html.Events.onFocus (SetFocus HasFocus)
                , Html.Events.onBlur (SetFocus HasNoFocus)
                , Html.Attributes.tabindex 0
                ]
            else
                []
    in
    List.concat
        [ scrollWheelZoom
        , doubleClickZoom
        , keyboardControl
        , [ Html.Events.on "mousedown"
                (Decode.map (DragStart >> DragMsg) Mouse.position)
          , Html.Events.onWithOptions "touchstart"
                { preventDefault = True
                , stopPropagation = False
                }
                (Decode.map touchesStartMsg touchesDecoder)
          , Html.Events.on "touchmove"
                (Decode.map touchesMoveMsg touchesDecoder)
          , Html.Events.on "touchend"
                (Decode.map touchesEndMsg (Decode.succeed (Tap (Position 0 0))))
          , Html.Events.on "touchcancel"
                (Decode.map touchesEndMsg (Decode.succeed (Tap (Position 0 0))))
          ]
        ]


viewPane : Config msg -> Transform -> List (Layer msg) -> Layer.Pane -> List (Svg msg)
viewPane (Config config) transform layers pane =
    layers
        |> List.filter (Layer.getPane >> (==) (Just pane))
        |> List.map (\layer -> Layer.render layer transform)


clientPosition : Decoder Point
clientPosition =
    Decode.map2 Point
        (Decode.field "offsetX" Decode.float)
        (Decode.field "offsetY" Decode.float)


type Touches
    = Tap Position
    | Pinch ( Position, Position )


touchesStartMsg : Touches -> Msg
touchesStartMsg touches =
    case touches of
        Tap position ->
            DragStart position |> DragMsg

        Pinch positions ->
            PinchStart positions |> PinchMsg


touchesMoveMsg : Touches -> Msg
touchesMoveMsg touches =
    case touches of
        Tap position ->
            DragAt position |> DragMsg

        Pinch positions ->
            PinchAt positions |> PinchMsg


touchesEndMsg : Touches -> Msg
touchesEndMsg touches =
    case touches of
        Tap position ->
            DragEnd position |> DragMsg

        Pinch positions ->
            PinchEnd positions |> PinchMsg


touchesDecoder : Decoder Touches
touchesDecoder =
    Decode.oneOf
        [ Decode.map Pinch pinchDecoder
        , Decode.map Tap tapDecoder
        ]


tapDecoder : Decoder Position
tapDecoder =
    tapDecoderAt 0


pinchDecoder : Decoder ( Position, Position )
pinchDecoder =
    Decode.map2 (,)
        (tapDecoderAt 0)
        (tapDecoderAt 1)


tapDecoderAt : Int -> Decoder Position
tapDecoderAt index =
    Decode.map2 Position
        (Decode.at [ "targetTouches", toString index, "clientX" ] Decode.int)
        (Decode.at [ "targetTouches", toString index, "clientY" ] Decode.int)
