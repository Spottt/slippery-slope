module SlippyMap.Static exposing (State, center, view)

{-| Just a static map.

@docs view, center, State

-}

import Html exposing (Html)
import SlippyMap.Geo.Location as Location exposing (Location)
import SlippyMap.Layer.LowLevel as Layer exposing (Layer)
import SlippyMap.Map.Config as Config
import SlippyMap.Map.State as State
import SlippyMap.Map.View as View


{-| Opaque internal state.
-}
type State
    = State State.State


{-| Center map at a given location and zoom level.
-}
center : Location -> Float -> State
center location zoom =
    State <|
        State.center location zoom


{-| Show a map, no interactions.
-}
view : { width : Int, height : Int } -> State -> List (Layer msg) -> Html msg
view dimensions (State state) =
    View.view (Config.staticConfig dimensions) state
