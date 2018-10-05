module Main exposing (AxisData, AxisX, AxisY, ChartRecord, ChartScalings, Datum, Flags, Model, Msg(..), RawCid, ScaledPoint, Stats, Tooltip, TooltipData(..), axisX, axisY, chartBottom, chartEnd, chartStart, chartTop, createDayTicks, createMaintenanceLine, createMaintenanceShape, createMajorTick, createMinorTick, createMonthTicks, createQcShape, createReviewLine, createReviewShape, createWeekTicks, createYearTicks, dayTickVals, deviations, doX, doY, findLowerTicks, findTicks, findUpperTicks, frameAxisX, frameAxisY, frameChart, frameLegend, genericShape, init, justTimeString, justValFn, main, maintenanceShape, majorYticks, meanLine, minorYticks, monthNumName, nominalLine, pdfLink, plusXdLine, prepareTime, readData, reviewShape, scaleXY, setChartScalings, shape, showTheTooltip, spacedRange, subscriptions, svgElements, tickBottom, timify, toPoints, update, view, weekTickVals)

import Axis2d exposing (Axis2d)
import BoundingBox2d exposing (BoundingBox2d)
import Browser
import Direction2d exposing (Direction2d)
import Frame2d exposing (Frame2d)
import Geometry.Svg as Svg
import Html exposing (Html, a, br, button, div, span, text)
import Html.Attributes exposing (href)
import Html.Events exposing (onClick)
import Html.Events.Extra.Mouse as M exposing (..)
import ISO8601
import Json.Encode as E
import LineSegment2d exposing (LineSegment2d)
import List.Extra
import Point2d exposing (Point2d)
import Polygon2d exposing (Polygon2d)
import Svg exposing (Svg)
import Svg.Attributes as Attributes exposing (..)
import Svg.Events as Events exposing (..)
import Triangle2d exposing (Triangle2d)
import Tuple



-- MAIN


main =
    Browser.element
        { init = init
        , update = update
        , subscriptions = subscriptions
        , view = view
        }



-- MAJORITY OF TYPE DECLARATIONS


type alias Model =
    { chartBoundingBox : Maybe BoundingBox2d
    , chartScalings : ChartScalings
    , chartType : String
    , data : List Datum
    , dateFrom : Maybe ISO8601.Time
    , dateTo : Maybe ISO8601.Time
    , flags : Flags
    , points : List Point2d
    , scaledPoints : List ScaledPoint
    , tooltip : Maybe Tooltip
    }


type alias Flags =
    { acqnominal : Float
    , analyteid : Int
    , chart_type : String
    , date_from : String
    , date_to : String
    , pdf : Bool
    , axes : AxisData
    , stats : Stats
    , maintenance_logs : List ChartRecord
    , reviews : List ChartRecord
    , qcresults : List RawCid
    }


type alias AxisData =
    { axis_x : AxisX, axis_y : AxisY }


type alias AxisX =
    { days : Int
    , weeks : Int
    , months : Int
    , years : Int
    , month_starts : List String
    , year_starts : List String
    , monday : String
    }


type alias AxisY =
    { min : Float
    , max : Float
    , ticks : Int
    , step : Float
    }


type alias ChartScalings =
    { sizeX : Float
    , sizeY : Float
    , distX : Float
    , distY : Float
    , scaleX : Float
    , scaleY : Float
    , offsetX : Float
    , offsetY : Float
    , upperBoundary : Float
    , lowerBoundary : Float
    }


type alias Datum =
    { time : Float
    , value : Float
    }


type alias Stats =
    { nominal : Float
    , mean : Float
    , deviation : Float
    }


type alias RawCid =
    { id : Int
    , c : Float
    , d : String
    }


type alias ScaledPoint =
    { point2d : Point2d
    , datum : Datum
    }


type alias ChartRecord =
    { on : String
    , by : String
    , comment : String
    }


type TooltipData
    = DataChartRecord ChartRecord
    | DataScaledPoint ScaledPoint


type alias Tooltip =
    { data : TooltipData
    , coordinates : ( Float, Float )
    , title : Maybe String
    }



-- INIT


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
    ( { chartBoundingBox = chartBoundingBox
      , chartScalings = setChartScalings flags chartBoundingBox
      , chartType = "default"
      , data = data
      , dateFrom = prepareTime flags.date_from
      , dateTo = prepareTime flags.date_to
      , flags = flags
      , points = points
      , scaledPoints = scaleXY flags data chartBoundingBox
      , tooltip = Nothing
      }
    , Cmd.none
    )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- UPDATE


type Msg
    = TooltipMouseEnter TooltipData ( Float, Float ) (Maybe String)
    | TooltipMouseLeave


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        TooltipMouseEnter tooltipData coordinates title ->
            ( { model | tooltip = Just (Tooltip tooltipData coordinates title) }
            , Cmd.none
            )

        TooltipMouseLeave ->
            ( { model | tooltip = Nothing }
            , Cmd.none
            )



-- JUST FUNCTIONS


justTimeString : Maybe ISO8601.Time -> String
justTimeString tv =
    case tv of
        Nothing ->
            ""

        Just tm ->
            ISO8601.toString tm


justValFn v fn =
    case v of
        Nothing ->
            0

        Just n ->
            fn n


prepareTime : String -> Maybe ISO8601.Time
prepareTime s =
    case ISO8601.fromString s of
        Err msg ->
            Nothing

        Result.Ok d ->
            Just d



-- OTHER FUNCTIONS


readData : Flags -> List Datum
readData flags =
    List.map (\d -> Datum (toFloat (timify d.d)) d.c) flags.qcresults


setChartScalings : Flags -> Maybe BoundingBox2d -> ChartScalings
setChartScalings flags boundingBox =
    let
        mean =
            flags.stats.mean

        deviation =
            flags.stats.deviation

        scalingFactor =
            3.5

        upperBoundary =
            mean + scalingFactor * deviation

        lowerBoundary =
            mean - scalingFactor * deviation

        -- sizes x & y of the view area
        dx =
            500.0

        dy =
            200.0

        -- distances x & y before scaling
        distX =
            chartEnd flags - chartStart flags

        distY =
            upperBoundary - lowerBoundary

        -- scale and offset
        scaleX =
            dx / distX

        offsetX =
            0 - chartStart flags

        scaleY =
            dy / distY

        offsetY =
            0 - lowerBoundary
    in
    { sizeX = dx
    , sizeY = dy
    , distX = distX
    , distY = distY
    , scaleX = scaleX
    , scaleY = scaleY
    , offsetX = offsetX
    , offsetY = offsetY
    , upperBoundary = upperBoundary
    , lowerBoundary = lowerBoundary
    }


chartStart : Flags -> Float
chartStart flags =
    toFloat (timify flags.date_from)


chartEnd : Flags -> Float
chartEnd flags =
    toFloat (timify flags.date_to)


chartBottom : Model -> Float
chartBottom model =
    doY model.chartScalings (deviations model -4.5)


chartTop : Model -> Float
chartTop model =
    doY model.chartScalings (deviations model 5)


tickBottom model =
    doY model.chartScalings (deviations model -4.7)



-- convert prescaled value to scaled one


doX : ChartScalings -> Float -> Float
doX cs x =
    cs.scaleX * (cs.offsetX + x)


doY : ChartScalings -> Float -> Float
doY cs y =
    cs.scaleY * (cs.offsetY + y)


scaleXY : Flags -> List Datum -> Maybe BoundingBox2d -> List ScaledPoint
scaleXY flags data boundingBox =
    let
        cs =
            setChartScalings flags boundingBox

        points =
            toPoints data
    in
    List.map
        (\d ->
            { point2d = Point2d.fromCoordinates ( doX cs d.time, doY cs d.value )
            , datum = d
            }
        )
        data


toPoints : List Datum -> List Point2d
toPoints data =
    List.map (\d -> Point2d.fromCoordinates ( d.time, d.value )) data


timify : String -> Int
timify d =
    case ISO8601.fromString d of
        Ok nd ->
            ISO8601.toTime nd

        Err _ ->
            timify "1970-01-01T00:00:00Z"


axisX : Model -> Svg msg
axisX model =
    Svg.lineSegment2d
        [ Attributes.stroke "black"
        , Attributes.strokeWidth "0.5"
        ]
        (LineSegment2d.fromEndpoints
            ( Point2d.fromCoordinates
                ( 0.0
                , chartBottom model
                )
            , Point2d.fromCoordinates
                ( doX model.chartScalings (chartEnd model.flags)
                , chartBottom model
                )
            )
        )


axisY : Model -> Svg msg
axisY model =
    Svg.lineSegment2d
        [ Attributes.stroke "black"
        , Attributes.strokeWidth "0.5"
        ]
        (LineSegment2d.fromEndpoints
            ( Point2d.fromCoordinates
                ( 0.0
                , chartBottom model
                )
            , Point2d.fromCoordinates
                ( 0.0
                , chartTop model
                )
            )
        )


nominalLine : Model -> Svg msg
nominalLine model =
    Svg.lineSegment2d
        [ Attributes.stroke "grey"
        , Attributes.strokeWidth "0.5"
        ]
        (LineSegment2d.fromEndpoints
            ( Point2d.fromCoordinates
                ( doX model.chartScalings (chartStart model.flags)
                , doY model.chartScalings model.flags.stats.nominal
                )
            , Point2d.fromCoordinates
                ( doX model.chartScalings (chartEnd model.flags)
                , doY model.chartScalings model.flags.stats.nominal
                )
            )
        )


meanLine : Model -> Svg msg
meanLine model =
    Svg.lineSegment2d
        [ Attributes.stroke "red"
        , Attributes.strokeWidth "0.5"
        ]
        (LineSegment2d.fromEndpoints
            ( Point2d.fromCoordinates
                ( doX model.chartScalings (chartStart model.flags)
                , doY model.chartScalings model.flags.stats.mean
                )
            , Point2d.fromCoordinates
                ( doX model.chartScalings (chartEnd model.flags)
                , doY model.chartScalings model.flags.stats.mean
                )
            )
        )


deviations : Model -> Float -> Float
deviations model x =
    model.flags.stats.mean + (model.flags.stats.deviation * x)


plusXdLine : Model -> Int -> Svg msg
plusXdLine model x =
    Svg.lineSegment2d
        [ Attributes.stroke "red"
        , Attributes.strokeWidth "0.4"
        ]
        (LineSegment2d.fromEndpoints
            ( Point2d.fromCoordinates
                ( doX model.chartScalings (chartStart model.flags)
                , doY model.chartScalings (deviations model (toFloat x))
                )
            , Point2d.fromCoordinates
                ( doX model.chartScalings (chartEnd model.flags)
                , doY model.chartScalings (deviations model (toFloat x))
                )
            )
        )


frameChart : Frame2d
frameChart =
    Frame2d.atPoint
        (Point2d.fromCoordinates ( 75, 300 ))
        |> Frame2d.reverseY


frameAxisX : Frame2d
frameAxisX =
    Frame2d.atPoint
        (Point2d.fromCoordinates ( 75, 350 ))
        |> Frame2d.reverseY


frameAxisY : Frame2d
frameAxisY =
    Frame2d.atPoint
        (Point2d.fromCoordinates ( 25, 300 ))
        |> Frame2d.reverseY


frameLegend : Frame2d
frameLegend =
    Frame2d.atPoint
        (Point2d.fromCoordinates ( 500, 100 ))
        |> Frame2d.reverseY


createQcShape : ScaledPoint -> Svg Msg
createQcShape point =
    Svg.polygon2d
        [ Attributes.fill "blue"
        , Attributes.stroke "black"
        , Attributes.strokeWidth "0.25"
        , M.onEnter (\event -> TooltipMouseEnter (DataScaledPoint point) event.pagePos Nothing)
        , M.onLeave (\event -> TooltipMouseLeave)
        ]
        (Polygon2d.singleLoop (shape point.point2d))


genericShape : Point2d -> Float -> List ( Float, Float ) -> List Point2d
genericShape point scale shapeCoordinates =
    let
        pointPair =
            ( Point2d.xCoordinate point, Point2d.yCoordinate point )

        scaledShapeCoordinates =
            List.map
                (\p -> ( Tuple.first p * scale, Tuple.second p * scale ))
                shapeCoordinates

        pc =
            List.map
                (\sc ->
                    ( Tuple.first pointPair + Tuple.first sc
                    , Tuple.second pointPair + Tuple.second sc
                    )
                )
                scaledShapeCoordinates
    in
    List.map
        (\c ->
            Point2d.fromCoordinates
                ( (Tuple.first pointPair + Tuple.first c) / 2.0
                , (Tuple.second pointPair + Tuple.second c) / 2.0
                )
        )
        pc


shape : Point2d -> List Point2d
shape point =
    -- draw tilted square around point coordinates
    genericShape point 4.5 [ ( 0.0, 1.0 ), ( 1.0, 0.0 ), ( 0.0, -1.0 ), ( -1.0, 0.0 ) ]


maintenanceShape : Point2d -> List Point2d
maintenanceShape point =
    genericShape point
        10.5
        [ ( 0.0, 1.0 ), ( 1.0, 0.0 ), ( 0.0, -1.0 ), ( -1.0, 0.0 ) ]


reviewShape : Point2d -> List Point2d
reviewShape point =
    genericShape point
        10.0
        [ ( 0.0, 0.0 )
        , ( 1.0, 1.0 )
        , ( 1.0, 0.0 )
        , ( 0.0, -1.0 )
        , ( -1.0, 0.0 )
        , ( -1.0, 1.0 )
        ]


createMaintenanceLine : Model -> ChartRecord -> Svg Msg
createMaintenanceLine model ml =
    let
        oni =
            toFloat (timify ml.on)

        ld =
            deviations model -4.5

        ud =
            deviations model 5
    in
    Svg.lineSegment2d
        [ Attributes.stroke "grey"
        , Attributes.strokeWidth "1"
        ]
        (LineSegment2d.fromEndpoints
            ( Point2d.fromCoordinates
                ( doX model.chartScalings oni, doY model.chartScalings ld )
            , Point2d.fromCoordinates
                ( doX model.chartScalings oni, doY model.chartScalings ud )
            )
        )


createReviewLine : Model -> ChartRecord -> Svg Msg
createReviewLine model ml =
    let
        oni =
            toFloat (timify ml.on)

        ld =
            deviations model -4.5

        ud =
            deviations model 4.5
    in
    Svg.lineSegment2d
        [ Attributes.stroke "green"
        , Attributes.strokeWidth "1"
        ]
        (LineSegment2d.fromEndpoints
            ( Point2d.fromCoordinates
                ( doX model.chartScalings oni, doY model.chartScalings ld )
            , Point2d.fromCoordinates
                ( doX model.chartScalings oni, doY model.chartScalings ud )
            )
        )


createMaintenanceShape : Model -> ChartRecord -> Svg Msg
createMaintenanceShape model ml =
    let
        oni =
            toFloat (timify ml.on)

        ud =
            deviations model 5

        point =
            Point2d.fromCoordinates ( doX model.chartScalings oni, doY model.chartScalings ud )
    in
    Svg.polygon2d
        [ Attributes.fill "red"
        , Attributes.stroke "black"
        , Attributes.strokeWidth "0.25"
        , M.onEnter (\event -> TooltipMouseEnter (DataChartRecord ml) event.pagePos (Just "Maintnance Log"))
        , M.onLeave (\event -> TooltipMouseLeave)
        ]
        (Polygon2d.singleLoop (maintenanceShape point))


createReviewShape : Model -> ChartRecord -> Svg Msg
createReviewShape model r =
    let
        oni =
            toFloat (timify r.on)

        ud =
            deviations model 4.5

        point =
            Point2d.fromCoordinates ( doX model.chartScalings oni, doY model.chartScalings ud )
    in
    Svg.polygon2d
        [ Attributes.fill "blue"
        , Attributes.stroke "black"
        , Attributes.strokeWidth "0.25"
        , M.onEnter (\event -> TooltipMouseEnter (DataChartRecord r) event.pagePos (Just "Review"))
        , M.onLeave (\event -> TooltipMouseLeave)
        ]
        (Polygon2d.singleLoop (reviewShape point))


createYearTicks model ys =
    let
        oni =
            toFloat (timify ys)

        yearPart =
            (ISO8601.fromTime (round oni)).year

        textX =
            doX model.chartScalings oni

        textY =
            doY model.chartScalings (deviations model -5.6)

        textPosition =
            Point2d.fromCoordinates ( textX, textY )

        mirrorAxis =
            Axis2d.through textPosition Direction2d.x

        tickText =
            Svg.text_
                [ fill "red"
                , x (String.fromFloat textX)
                , y (String.fromFloat textY)
                ]
                [ text (String.fromInt yearPart) ]
    in
    Svg.g []
        [ Svg.lineSegment2d
            [ Attributes.stroke "blue"
            , Attributes.strokeWidth "4"
            ]
            (LineSegment2d.fromEndpoints
                ( Point2d.fromCoordinates
                    ( doX model.chartScalings oni, doY model.chartScalings (deviations model -4.5) )
                , Point2d.fromCoordinates
                    ( doX model.chartScalings oni, doY model.chartScalings (deviations model -4.9) )
                )
            )
        , Svg.mirrorAcross mirrorAxis tickText
        ]


monthNumName : Int -> Maybe String
monthNumName monthPartNumber =
    List.Extra.getAt
        (monthPartNumber - 1)
        [ "Jan" -- year is in place of Jan
        , "Feb"
        , "Mar"
        , "Apr"
        , "May"
        , "Jun"
        , "Jul"
        , "Aug"
        , "Sep"
        , "Oct"
        , "Nov"
        , "Dec"
        ]


createMonthTicks model ms =
    let
        timi =
            timify ms

        oni =
            toFloat timi

        monthPartNumber =
            -- add 1 hour to fix daylight saving time offset problems
            -- for the beginning of the month
            (ISO8601.fromTime (timi + (1000 * 3600 * 1))).month

        monthPart =
            monthNumName monthPartNumber

        textX =
            Debug.log
                (Debug.toString
                    { ms = ms
                    , timi = timi
                    , monthPartNumber = monthPartNumber
                    , monthPart = monthPart
                    }
                )
                (doX model.chartScalings oni)

        textY =
            doY model.chartScalings (deviations model -5.2)

        textPosition =
            Point2d.fromCoordinates ( textX, textY )

        mirrorAxis =
            Axis2d.through textPosition Direction2d.x

        months =
            model.flags.axes.axis_x.month_starts

        reducedMonthPart =
            if List.length months > 12 then
                Just ""

            else
                monthPart

        tickText =
            Svg.text_
                [ fill "black"
                , x (String.fromFloat textX)
                , y (String.fromFloat textY)
                ]
                [ text (Maybe.withDefault "" reducedMonthPart) ]
    in
    Svg.g []
        [ Svg.lineSegment2d
            [ Attributes.stroke "black"
            , Attributes.strokeWidth "3"
            ]
            (LineSegment2d.fromEndpoints
                ( Point2d.fromCoordinates
                    ( doX model.chartScalings oni, doY model.chartScalings (deviations model -4.5) )
                , Point2d.fromCoordinates
                    ( doX model.chartScalings oni, doY model.chartScalings (deviations model -4.8) )
                )
            )
        , Svg.mirrorAcross mirrorAxis tickText
        ]


createWeekTicks model ws =
    let
        oni =
            toFloat ws
    in
    Svg.lineSegment2d
        [ Attributes.stroke "black"
        , Attributes.strokeWidth "1.5"
        ]
        (LineSegment2d.fromEndpoints
            ( Point2d.fromCoordinates
                ( doX model.chartScalings oni, doY model.chartScalings (deviations model -4.5) )
            , Point2d.fromCoordinates
                ( doX model.chartScalings oni, doY model.chartScalings (deviations model -4.7) )
            )
        )


createDayTicks model ds =
    let
        oni =
            toFloat ds
    in
    Svg.lineSegment2d
        [ Attributes.stroke "black"
        , Attributes.strokeWidth "1"
        ]
        (LineSegment2d.fromEndpoints
            ( Point2d.fromCoordinates
                ( doX model.chartScalings oni, doY model.chartScalings (deviations model -4.5) )
            , Point2d.fromCoordinates
                ( doX model.chartScalings oni, doY model.chartScalings (deviations model -4.6) )
            )
        )


createMajorTick model mt =
    let
        ox =
            chartStart model.flags

        textX =
            doX model.chartScalings ox - 40

        textY =
            doY model.chartScalings mt

        textPosition =
            Point2d.fromCoordinates ( textX, textY )

        mirrorAxis =
            Axis2d.through textPosition Direction2d.x

        tickText =
            Svg.text_
                [ fill "black"
                , x (String.fromFloat textX)
                , y (String.fromFloat textY)
                ]
                [ text (String.fromFloat mt) ]
    in
    Svg.g []
        [ Svg.lineSegment2d
            [ Attributes.stroke "black"
            , Attributes.strokeWidth "1.5"
            ]
            (LineSegment2d.fromEndpoints
                ( Point2d.fromCoordinates
                    ( doX model.chartScalings ox, doY model.chartScalings mt )
                , Point2d.fromCoordinates
                    ( doX model.chartScalings ox - 10, doY model.chartScalings mt )
                )
            )

        -- we have to flip text manually
        , Svg.mirrorAcross mirrorAxis tickText
        ]


createMinorTick model mt =
    let
        ox =
            chartStart model.flags
    in
    Svg.lineSegment2d
        [ Attributes.stroke "black"
        , Attributes.strokeWidth "0.75"
        ]
        (LineSegment2d.fromEndpoints
            ( Point2d.fromCoordinates
                ( doX model.chartScalings ox, doY model.chartScalings mt )
            , Point2d.fromCoordinates
                ( doX model.chartScalings ox - 7, doY model.chartScalings mt )
            )
        )


weekTickVals model =
    let
        axis_x =
            model.flags.axes.axis_x

        first =
            model.flags.date_from

        last =
            model.flags.date_to

        weekMiliseconds =
            1000 * 3600 * 24 * 7

        afterMonday =
            spacedRange weekMiliseconds (timify axis_x.monday) (timify last)

        firstDay =
            timify first
    in
    if model.flags.axes.axis_x.weeks < 100 then
        List.filter (\d -> d >= firstDay) afterMonday

    else
        []


dayTickVals model =
    let
        first =
            model.flags.date_from

        last =
            model.flags.date_to

        dayMiliseconds =
            1000 * 3600 * 24

        diff =
            ISO8601.diff (ISO8601.fromTime (timify last)) (ISO8601.fromTime (timify first))

        days =
            diff // dayMiliseconds
    in
    if model.flags.axes.axis_x.days < 100 then
        spacedRange dayMiliseconds (timify first) (timify last)

    else
        []



-- ticks below the max value


findLowerTicks : Float -> Float -> Float -> List Float -> List Float
findLowerTicks val bound step acc =
    if val < bound then
        acc

    else
        findLowerTicks (val - step) bound step (val :: acc)



-- ticks above the max value


findUpperTicks : Float -> Float -> Float -> List Float -> List Float
findUpperTicks val bound step acc =
    if val > bound then
        List.reverse acc

    else
        findUpperTicks (val + step) bound step (val :: acc)


findTicks : Float -> Float -> Float -> Float -> List Float -> List Float
findTicks val ubound lbound step acc =
    let
        ll =
            findLowerTicks val lbound step []

        ul =
            findUpperTicks val ubound step []
    in
    ll ++ Maybe.withDefault [] (List.tail ul)


majorYticks : Model -> List Float
majorYticks model =
    let
        axis_y =
            model.flags.axes.axis_y

        upperBoundary =
            model.chartScalings.upperBoundary

        lowerBoundary =
            chartBottom model - axis_y.step

        all_ticks =
            findTicks axis_y.max upperBoundary lowerBoundary axis_y.step []
    in
    List.filter (\t -> (t >= deviations model -4.5) && (t <= deviations model 4)) all_ticks


minorYticks : Model -> List Float
minorYticks model =
    let
        axis_y =
            model.flags.axes.axis_y

        upperBoundary =
            model.chartScalings.upperBoundary

        lowerBoundary =
            chartBottom model - axis_y.step

        scaling =
            -- reduce number of minor ticks if too many
            -- by increasing the distance between them
            if axis_y.step > 10 then
                5

            else
                1

        tickStep =
            axis_y.step / axis_y.step * scaling

        all_ticks =
            findTicks axis_y.max upperBoundary lowerBoundary tickStep []
    in
    List.filter (\t -> (t >= deviations model -4.5) && (t <= deviations model 4)) all_ticks


spacedRange : Int -> Int -> Int -> List Int
spacedRange spacing first last =
    List.range 0 ((last - first) // spacing)
        |> List.map (\n -> first + n * spacing)


svgElements : Model -> List (Svg Msg)
svgElements model =
    [ Svg.placeIn frameChart (axisX model)
    , Svg.placeIn frameChart (axisY model)
    , Svg.placeIn frameChart (nominalLine model)
    , Svg.placeIn frameChart (meanLine model)
    , Svg.placeIn frameChart (plusXdLine model 3)
    , Svg.placeIn frameChart (plusXdLine model 2)
    , Svg.placeIn frameChart (plusXdLine model -2)
    , Svg.placeIn frameChart (plusXdLine model -3)
    ]
        ++ List.map (\p -> Svg.placeIn frameChart (createQcShape p)) model.scaledPoints
        ++ List.map (\ml -> Svg.placeIn frameChart (createMaintenanceLine model ml)) model.flags.maintenance_logs
        ++ List.map (\ml -> Svg.placeIn frameChart (createMaintenanceShape model ml)) model.flags.maintenance_logs
        ++ List.map (\r -> Svg.placeIn frameChart (createReviewLine model r)) model.flags.reviews
        ++ List.map (\r -> Svg.placeIn frameChart (createReviewShape model r)) model.flags.reviews
        ++ List.map (\ys -> Svg.placeIn frameChart (createYearTicks model ys)) model.flags.axes.axis_x.year_starts
        ++ List.map (\ms -> Svg.placeIn frameChart (createMonthTicks model ms)) model.flags.axes.axis_x.month_starts
        ++ List.map (\ms -> Svg.placeIn frameChart (createWeekTicks model ms)) (weekTickVals model)
        ++ List.map (\ms -> Svg.placeIn frameChart (createDayTicks model ms)) (dayTickVals model)
        ++ List.map (\mt -> Svg.placeIn frameChart (createMajorTick model mt)) (majorYticks model)
        ++ List.map (\mt -> Svg.placeIn frameChart (createMinorTick model mt)) (minorYticks model)


pdfLink : Model -> Html Msg
pdfLink model =
    if model.flags.pdf then
        div [] []

    else
        a
            [ href
                ("/analytes/"
                    ++ Debug.toString model.flags.analyteid
                    ++ "/pdf_report"
                    ++ "/chart_type/"
                    ++ model.chartType
                    ++ "/dating_from/"
                    ++ String.slice 0 10 (justTimeString model.dateFrom)
                    ++ "/dating_to/"
                    ++ String.slice 0 10 (justTimeString model.dateTo)
                )
            , target "_blank"
            ]
            [ text "Download the PDF" ]


showTheTooltip : Model -> Html Msg
showTheTooltip model =
    case model.tooltip of
        Nothing ->
            div [] []

        Just tt ->
            div
                [ class "log-record-tooltip"
                , style
                    ("left: "
                        ++ String.fromFloat (10 + Tuple.first tt.coordinates)
                        ++ "px; "
                        ++ "top: "
                        ++ String.fromFloat (10 + Tuple.second tt.coordinates)
                        ++ "px;"
                    )
                ]
                (case tt.data of
                    DataChartRecord d ->
                        [ span [ class "tool-tip-title" ] [ text (Maybe.withDefault "" tt.title) ]
                        , br [] []
                        , span [ class "tool-tip-title" ] [ text "On: " ]
                        , span [] [ text d.on ]
                        , br [] []
                        , span [ class "tool-tip-title" ] [ text "By: " ]
                        , span [] [ text d.by ]
                        , br [] []
                        , span [ class "tool-tip-title" ] [ text "Comment: " ]
                        , span [] [ text d.comment ]
                        ]

                    DataScaledPoint d ->
                        let
                            tm =
                                ISO8601.fromTime (floor d.datum.time)

                            t2 =
                                ISO8601.toString tm

                            t3 =
                                List.head (String.split "Z" t2)

                            t4 =
                                String.split "T" (Maybe.withDefault "" t3)

                            dx =
                                List.head t4

                            tx =
                                case List.tail t4 of
                                    Nothing ->
                                        ""

                                    Just s ->
                                        Maybe.withDefault "" (List.head s)
                        in
                        [ span
                            [ class "tool-tip-title" ]
                            [ text "Date: " ]
                        , span [] [ text (Maybe.withDefault "" dx) ]
                        , br [] []
                        , span [ class "tool-tip-title" ] [ text "Time: " ]
                        , span [] [ text tx ]
                        , br [] []
                        , span [ class "tool-tip-title" ]
                            [ text "Concentration: " ]
                        , span
                            []
                            [ text (String.fromFloat d.datum.value) ]
                        ]
                )


view : Model -> Html Msg
view model =
    div [ style "border: solid yellow 1px;" ]
        [ div [ style "margin: auto ; width:700px" ]
            [ Svg.svg
                [ height "400"
                , viewBox "0 0 700 400"
                , style "border: solid #abc 1px;"
                ]
                [ Svg.g []
                    (svgElements model)
                ]
            ]
        , showTheTooltip model
        , div [ style "margin-top: 2em; text-align: center;" ]
            [ pdfLink model
            ]
        , div [ style "height:1em;" ] []

        -- , div [] [ text (Debug.toString model.flags) ]
        ]
