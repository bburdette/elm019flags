module Main exposing (Flags, Model, Msg(..), init, main, update, view)

import BoundingBox2d exposing (BoundingBox2d)
import Browser
import Frame2d exposing (Frame2d)
import Geometry.Svg as Svg
import Html exposing (Html, button, div, text)
import Html.Events exposing (onClick)
import ISO8601
import Point2d exposing (Point2d)
import Polygon2d exposing (Polygon2d)
import Svg exposing (Svg)
import Svg.Attributes as Attributes exposing (..)
import Triangle2d exposing (Triangle2d)
import Tuple


main =
    Browser.element
        { init = init
        , update = update
        , subscriptions = \_ -> Sub.none
        , view = view
        }


type alias Model =
    { flags : Flags
    , level : Int
    , data : List Datum
    , points : List Point2d
    , chartBoundingBox : Maybe BoundingBox2d
    , scaledPoints : List Point2d
    }


init : Flags -> ( Model, Cmd Msg )
init flags =
    let
        data =
            readData flags

        points =
            toPoints data

        chartBoundingBox =
            BoundingBox2d.containingPoints points
    in
    ( { flags = flags
      , level = 0
      , data = data
      , points = points
      , chartBoundingBox = chartBoundingBox
      , scaledPoints = scaleXY points chartBoundingBox
      }
    , Cmd.none
    )


justin v fn =
    case v of
        Nothing ->
            0

        Just n ->
            fn n


scaleXY points boundingBox =
    let
        dx =
            40000.0

        dy =
            1000.0

        sx =
            dx / justin boundingBox BoundingBox2d.maxX

        ox =
            0
                - justin
                    boundingBox
                    BoundingBox2d.minX

        sy =
            dy / justin boundingBox BoundingBox2d.maxY

        oy =
            0
                - justin boundingBox
                    BoundingBox2d.minY
    in
    Debug.log
        ("scaling and offset values "
            ++ Debug.toString [ sx, ox, sy, oy ]
            ++ "\n bounding box "
            ++ Debug.toString boundingBox
            ++ "\n minx of bounding box "
            ++ Debug.toString
                (case boundingBox of
                    Nothing ->
                        0

                    Just n ->
                        BoundingBox2d.minX n
                )
        )
        List.map
        (\p ->
            Point2d.fromCoordinates
                ( sx * (ox + Point2d.xCoordinate p)
                , sy * (oy + Point2d.yCoordinate p)
                )
        )
        points


toPoints data =
    List.map (\d -> Point2d.fromCoordinates ( d.time, d.value )) data


type alias Datum =
    { time : Float
    , value : Float
    }


type alias ChartRecord =
    { on : String
    , comment : String
    , by : String
    }


type alias Stats =
    { nominal : Float
    , mean : Float
    , deviation : Float
    }


type alias Flags =
    { acqnominal : Float
    , analyteid : Int
    , chart_type : String
    , date_from : String
    , date_to : String
    , pdf : Bool
    , stats : Stats
    , maintenance_logs : List ChartRecord
    , reviews : List ChartRecord
    , qcresults : List RawCid
    }


type alias RawCid =
    { id : Int
    , c : Float
    , d : String
    }


type Msg
    = Increment
    | Decrement


update msg model =
    case msg of
        Increment ->
            ( { model | level = model.level + 1 }, Cmd.none )

        Decrement ->
            ( { model | level = model.level - 1 }, Cmd.none )


timify d =
    case ISO8601.fromString d of
        Ok nd ->
            ISO8601.toTime nd

        Err _ ->
            timify "1970-01-01T00:00:00Z"


triangle : Svg Msg
triangle =
    Svg.triangle2d
        [ Attributes.stroke "blue"
        , Attributes.strokeWidth "10"
        , Attributes.strokeLinejoin "round"
        , Attributes.fill "orange"
        ]
        (Triangle2d.fromVertices
            ( Point2d.fromCoordinates ( 0, 0 )
            , Point2d.fromCoordinates ( 60, 5 )
            , Point2d.fromCoordinates ( 5, 60 )
            )
        )


vertices =
    [ Point2d.fromCoordinates ( 0, 0 )
    , Point2d.fromCoordinates ( 100, 0 )
    , Point2d.fromCoordinates ( 0, 100 )
    ]


rcc =
    [ ( 0, 0 ), ( 50, 0 ), ( 50, 50 ), ( 0, 50 ) ]


rect cc =
    List.map (\c -> Point2d.fromCoordinates c) cc


stamp col cc =
    Svg.polygon2d
        [ Attributes.fill col
        , Attributes.stroke "blue"
        , Attributes.strokeWidth "2"
        ]
        (Polygon2d.singleLoop (rect cc))


stamp2 col cc =
    Svg.polygon2d
        [ Attributes.fill col
        , Attributes.stroke "black"
        , Attributes.strokeWidth "0.5"
        ]
        (Polygon2d.singleLoop cc)


frameChart =
    Frame2d.atPoint
        (Point2d.fromCoordinates ( 100, 300 ))
        |> Frame2d.reverseY


frameAxisX =
    Frame2d.atPoint
        (Point2d.fromCoordinates ( 100, 350 ))
        |> Frame2d.reverseY


frameAxisY =
    Frame2d.atPoint
        (Point2d.fromCoordinates ( 50, 300 ))
        |> Frame2d.reverseY


frameLegend =
    Frame2d.atPoint
        (Point2d.fromCoordinates ( 300, 100 ))
        |> Frame2d.reverseY


placed model =
    Svg.g []
        [ Svg.placeIn frameChart (stamp "yellow" rcc)
        , Svg.placeIn frameChart (stamp2 "orange" model.scaledPoints)
        , Svg.placeIn frameAxisX (stamp "blue" rcc)
        , Svg.placeIn frameAxisY (stamp "green" rcc)
        , Svg.placeIn frameLegend (stamp "red" rcc)
        ]


readData flags =
    let
        qcr =
            List.map (\d -> Datum (toFloat (timify d.d)) d.c) flags.qcresults
    in
    -- at the moment we read only the first 5 results for easy debugging
    -- List.take 5 qcr
    qcr


view model =
    div []
        [ div []
            [ Svg.svg
                [ width "420"
                , height "420"
                , viewBox "0 0 420 420"
                , style "border: solid red 1px;"
                ]
                [ placed model ]
            ]
        , button [ onClick Decrement ] [ text "-" ]
        , div [] [ text (String.fromInt model.level) ]
        , button [ onClick Increment ] [ text "+" ]
        , div [] [ text "We have lift off" ]
        , div [] [ text (Debug.toString model.data) ]
        , div [ style "height:5em;" ] []
        ]
