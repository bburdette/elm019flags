module App.View exposing (axisX, axisY, createDayTicks, createMaintenanceLine, createMaintenanceShape, createMeanLine, createMinorTick, createMonthTicks, createNominalLine, createQcShape, createReviewLine, createReviewShape, createWeekTicks, createXsdlLine, createYearTicks, dayTickVals, findTicks, findTicks1, frameAxisX, frameAxisY, frameChart, frameLegend, genericShape, maintenanceShape, pdfLink, reviewShape, shape, showTheTooltip, spacedRange, svgElements, view, weekTickVals)

import App.Model exposing (..)
import App.Utilities exposing (..)
import Axis2d exposing (Axis2d)
import Direction2d exposing (Direction2d)
import Frame2d exposing (Frame2d)
import Geometry.Svg as Svg
import Html exposing (Html, a, br, button, div, span, text)
import Html.Attributes exposing (href)
import Html.Events exposing (onClick)
import Html.Events.Extra.Mouse as M exposing (..)
import ISO8601
import LineSegment2d exposing (LineSegment2d)
import List.Extra
import Point2d exposing (Point2d)
import Polygon2d exposing (Polygon2d)
import Svg exposing (Svg)
import Svg.Attributes as Attributes exposing (..)
import Svg.Events as Events exposing (..)


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
            deviations model lodev List.minimum

        ud =
            deviations model 5 List.maximum
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
            deviations model lodev List.minimum

        ud =
            deviations model 4.5 List.maximum
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
            deviations model 5 List.maximum

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
            deviations model 4.5 List.maximum

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


createMeanLine : Model -> ( Int, Maybe Int ) -> Svg msg
createMeanLine model timeSection =
    let
        st =
            toFloat
                (Basics.max (Tuple.first timeSection) (timify model.flags.date_from))

        ted =
            timify model.flags.date_to

        et =
            toFloat
                (Basics.min ted (Maybe.withDefault ted (Tuple.second timeSection)))

        sd =
            findStatForTime model.flags.stats (round st)

        dmean =
            case sd of
                Nothing ->
                    150.0

                Just v ->
                    v.mean
    in
    Svg.lineSegment2d
        [ Attributes.stroke "red"
        , Attributes.strokeWidth "1"
        ]
        (LineSegment2d.fromEndpoints
            ( Point2d.fromCoordinates
                ( doX model.chartScalings st, doY model.chartScalings dmean )
            , Point2d.fromCoordinates
                ( doX model.chartScalings et, doY model.chartScalings dmean )
            )
        )


createNominalLine : Model -> ( Int, Maybe Int ) -> Svg msg
createNominalLine model timeSection =
    let
        st =
            toFloat
                (Basics.max (Tuple.first timeSection) (timify model.flags.date_from))

        ted =
            timify model.flags.date_to

        et =
            toFloat
                (Basics.min ted (Maybe.withDefault ted (Tuple.second timeSection)))

        sd =
            findStatForTime model.flags.stats (round st)

        dmean =
            case sd of
                Nothing ->
                    150.0

                Just v ->
                    v.nominal
    in
    Svg.lineSegment2d
        [ Attributes.stroke "grey"
        , Attributes.strokeWidth "2"
        ]
        (LineSegment2d.fromEndpoints
            ( Point2d.fromCoordinates
                ( doX model.chartScalings st, doY model.chartScalings dmean )
            , Point2d.fromCoordinates
                ( doX model.chartScalings et, doY model.chartScalings dmean )
            )
        )


createXsdlLine : Float -> Model -> ( Int, Maybe Int ) -> Svg msg
createXsdlLine xsd model timeSection =
    let
        st =
            toFloat
                (Basics.max (Tuple.first timeSection) (timify model.flags.date_from))

        ted =
            timify model.flags.date_to

        et =
            toFloat
                (Basics.min ted (Maybe.withDefault ted (Tuple.second timeSection)))

        sd =
            findStatForTime model.flags.stats (round st)

        dmean =
            case sd of
                Nothing ->
                    0.0

                Just v ->
                    v.mean

        ddev =
            case sd of
                Nothing ->
                    0.0

                Just v ->
                    v.deviation

        dx =
            dmean + xsd * ddev
    in
    Svg.lineSegment2d
        [ Attributes.stroke "red"
        , Attributes.strokeWidth "1"
        ]
        (LineSegment2d.fromEndpoints
            ( Point2d.fromCoordinates
                ( doX model.chartScalings st, doY model.chartScalings dx )
            , Point2d.fromCoordinates
                ( doX model.chartScalings et, doY model.chartScalings dx )
            )
        )


createYearTicks model ys =
    let
        oni =
            toFloat (timify ys)

        yearPart =
            (ISO8601.fromTime (round oni)).year

        textX =
            doX model.chartScalings oni

        textY =
            doY model.chartScalings (deviations model -5.6 List.minimum)

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
                    ( doX model.chartScalings oni, doY model.chartScalings (deviations model lodev List.minimum) )
                , Point2d.fromCoordinates
                    ( doX model.chartScalings oni, doY model.chartScalings (deviations model -4.9 List.minimum) )
                )
            )
        , Svg.mirrorAcross mirrorAxis tickText
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
            doY model.chartScalings (deviations model -5.2 List.minimum)

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
                    ( doX model.chartScalings oni, doY model.chartScalings (deviations model lodev List.minimum) )
                , Point2d.fromCoordinates
                    ( doX model.chartScalings oni, doY model.chartScalings (deviations model -4.8 List.minimum) )
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
                ( doX model.chartScalings oni, doY model.chartScalings (deviations model lodev List.minimum) )
            , Point2d.fromCoordinates
                ( doX model.chartScalings oni, doY model.chartScalings (deviations model -4.7 List.minimum) )
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
                ( doX model.chartScalings oni, doY model.chartScalings (deviations model lodev List.minimum) )
            , Point2d.fromCoordinates
                ( doX model.chartScalings oni, doY model.chartScalings (deviations model -4.6 List.minimum) )
            )
        )


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
            findTicks axis_y.max lowerBoundary axis_y.step
    in
    List.filter (\t -> (t >= deviations model lodev List.minimum) && (t <= deviations model hidev List.maximum)) all_ticks


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
            findTicks axis_y.max lowerBoundary tickStep
    in
    List.filter (\t -> (t >= deviations model lodev List.minimum) && (t <= deviations model hidev List.maximum)) all_ticks



-- ticks below the max value


findTicks1 : Float -> Float -> Float -> List Float -> List Float
findTicks1 val bound step acc =
    if (val < bound) || (List.length acc > 250) then
        acc

    else
        findTicks1 (val - step) bound step (val :: acc)


findTicks : Float -> Float -> Float -> List Float
findTicks val lbound step =
    findTicks1 val lbound step []


spacedRange : Int -> Int -> Int -> List Int
spacedRange spacing first last =
    List.range 0 ((last - first) // spacing)
        |> List.map (\n -> first + n * spacing)


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


pdfLink : Model -> Html Msg
pdfLink model =
    if model.flags.pdf then
        div [] []

    else
        a
            [ href
                ("/analytes/"
                    ++ String.fromInt model.flags.analyteid
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


svgElements : Model -> List (Svg Msg)
svgElements model =
    [ Svg.placeIn frameChart (axisX model)
    , Svg.placeIn frameChart (axisY model)
    ]
        ++ List.map (\ml -> Svg.placeIn frameChart (createMaintenanceLine model ml)) model.flags.maintenance_logs
        ++ List.map (\ml -> Svg.placeIn frameChart (createMaintenanceShape model ml)) model.flags.maintenance_logs
        ++ List.map (\r -> Svg.placeIn frameChart (createReviewLine model r)) model.flags.reviews
        ++ List.map (\r -> Svg.placeIn frameChart (createReviewShape model r)) model.flags.reviews
        ++ List.map (\s -> Svg.placeIn frameChart (createNominalLine model s)) (statStartTuples model)
        ++ List.map (\s -> Svg.placeIn frameChart (createMeanLine model s)) (statStartTuples model)
        ++ List.map (\s -> Svg.placeIn frameChart (createXsdlLine 3.0 model s)) (statStartTuples model)
        ++ List.map (\s -> Svg.placeIn frameChart (createXsdlLine 2.0 model s)) (statStartTuples model)
        ++ List.map (\s -> Svg.placeIn frameChart (createXsdlLine -2.0 model s)) (statStartTuples model)
        ++ List.map (\s -> Svg.placeIn frameChart (createXsdlLine -3.0 model s)) (statStartTuples model)
        ++ List.map (\p -> Svg.placeIn frameChart (createQcShape p)) model.scaledPoints
        ++ List.map (\ys -> Svg.placeIn frameChart (createYearTicks model ys)) model.flags.axes.axis_x.year_starts
        ++ List.map (\ms -> Svg.placeIn frameChart (createMonthTicks model ms)) model.flags.axes.axis_x.month_starts
        ++ List.map (\ms -> Svg.placeIn frameChart (createWeekTicks model ms)) (weekTickVals model)
        ++ List.map (\ms -> Svg.placeIn frameChart (createDayTicks model ms)) (dayTickVals model)
        ++ List.map (\mt -> Svg.placeIn frameChart (createMajorTick model mt)) (majorYticks model)
        ++ List.map (\mt -> Svg.placeIn frameChart (createMinorTick model mt)) (minorYticks model)


view : Model -> Html Msg
view model =
    div [ style "border: solid yellow 1px;" ]
        [ div [ style "margin: auto ; width:700px" ]
            [ Svg.svg
                [ height "400"
                , viewBox "0 0 700 400"
                , style "border: solid #abc 1px;"
                ]
                [ Svg.g [] (svgElements model) ]
            ]
        , showTheTooltip model
        , div [ style "margin-top: 2em; text-align: center;" ]
            [ pdfLink model
            ]
        , div [ style "height:1em;" ] []
        , div [ style "border: blue solid 3px;" ] [ text (Debug.toString model.flags) ]
        ]