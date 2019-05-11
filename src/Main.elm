module Main exposing (main)

import Browser
import Components exposing (uiArray)
import Dict exposing (Dict)
import Element exposing (Element, alignRight, el, fill, height, padding, rgb255, spacing, text, width)
import Element.Background as Background
import Element.Border as Border
import Element.Events as Events
import Element.Font as Font
import Element.Input as Input
import Html exposing (Html)
import Platform exposing (Program)
import Set exposing (Set)


type alias Model =
    { templates : List String
    , selected : Dict String CardInformation
    , players : List String
    , playersRawText : String
    , openCard : Maybe String
    }


type alias CardInformation =
    { count : Int
    , players : Set String
    }


newCard : CardInformation
newCard =
    { count = 1, players = Set.empty }


type Msg
    = NoOp
    | AddRoleButtonClick String
    | RemoveRoleButtonClick String
    | TypePlayerNames String
    | SelectCard String
    | CloseCard
    | AssignPlayerToRole String String
    | RemovePlayerFromRole String String


init : Model
init =
    { templates = [ "Werwolf", "Seherin", "Hexe", "Seelenretter", "Vampir", "Jäger" ]
    , selected = Dict.empty
    , players = [ "Ada", "Berd", "Carol", "Dave", "Esther", "Felix", "Greta" ]
    , playersRawText = ""
    , openCard = Nothing
    }


main : Program () Model Msg
main =
    Browser.sandbox { init = init, update = update, view = view }


update : Msg -> Model -> Model
update msg model =
    case msg of
        AddRoleButtonClick name ->
            { model | selected = addCard name model.selected }

        NoOp ->
            model

        RemoveRoleButtonClick template ->
            { model | selected = removeCard template model.selected }

        TypePlayerNames rawText ->
            setPlayerNames rawText model

        SelectCard identifier ->
            { model | openCard = Just identifier }

        CloseCard ->
            { model | openCard = Nothing }

        AssignPlayerToRole cardName playerName ->
            assignPlayerToRole cardName playerName model

        RemovePlayerFromRole cardName playerName ->
            removePlayerFromRole cardName playerName model


addCard : String -> Dict String CardInformation -> Dict String CardInformation
addCard template dict =
    let
        closure x =
            case x of
                Just a ->
                    Just { a | count = a.count + 1 }

                Nothing ->
                    Just newCard
    in
    Dict.update template closure dict


removeCard : String -> Dict String CardInformation -> Dict String CardInformation
removeCard template dict =
    let
        substract : CardInformation -> Maybe CardInformation
        substract cardInfo =
            if cardInfo.count > 1 then
                Just { cardInfo | count = cardInfo.count - 1 }

            else
                Nothing
    in
    Dict.update template (Maybe.andThen substract) dict


cardCount : Model -> Int
cardCount model =
    List.sum <| List.map (\x -> x.count) <| Dict.values model.selected



-- setPlayerCount : String -> Model -> Model
-- setPlayerCount rawText model =
--     let
--         newPlayerCount =
--             String.toInt rawText |> Maybe.withDefault ()
--     in
--     { model | playerCount = newPlayerCount, playerCountRawText = rawText }


setPlayerNames : String -> Model -> Model
setPlayerNames rawText model =
    let
        names =
            parsePlayerNames rawText

        newPlayers =
            if List.length names > 0 then
                names

            else
                model.players
    in
    { model | players = newPlayers, playersRawText = rawText }


parsePlayerNames : String -> List String
parsePlayerNames rawText =
    rawText
        |> String.split ","
        |> List.map String.trim
        |> List.filter (not << String.isEmpty)


playerCount : Model -> Int
playerCount model =
    List.length model.players


assignPlayerToRole : String -> String -> Model -> Model
assignPlayerToRole cardName playerName model =
    { model | selected = Dict.update cardName (Maybe.map <| assignPlayer playerName) model.selected }


assignPlayer : String -> CardInformation -> CardInformation
assignPlayer name cardInfo =
    { cardInfo | players = Set.insert name cardInfo.players }


removePlayerFromRole : String -> String -> Model -> Model
removePlayerFromRole cardName playerName model =
    { model | selected = Dict.update cardName (Maybe.map <| removePlayer playerName) model.selected }


removePlayer : String -> CardInformation -> CardInformation
removePlayer name cardInfo =
    { cardInfo | players = Set.remove name cardInfo.players }



-------------------------------
-- Here starts the View Code --
-------------------------------


view : Model -> Html Msg
view model =
    Element.layout [ width fill ]
        (mainView model)


mainView : Model -> Element Msg
mainView model =
    Element.column [ spacing 20, padding 10, width fill ]
        [ gameSetupHeader model
        , addCardsView model.templates
        , roleList model
        ]


gameSetupHeader : Model -> Element Msg
gameSetupHeader model =
    Element.row [ width fill ]
        [ playerCountEditBox model ]


playerCountEditBox : Model -> Element Msg
playerCountEditBox model =
    Input.text []
        { onChange = TypePlayerNames
        , text = model.playersRawText
        , placeholder = Just <| Input.placeholder [] <| text <| String.join ", " model.players
        , label = Input.labelAbove [] (text "Mitspieler: ")
        }


addCardsView : List String -> Element Msg
addCardsView templates =
    Element.column [ width fill, spacing 5 ]
        [ text "Sonderrollen hinzufügen:"
        , buttonArray templates
        ]


buttonArray : List String -> Element Msg
buttonArray templates =
    uiArray 4
        (List.map roleButton templates)


roleButton : String -> Element Msg
roleButton name =
    el
        [ Background.color (rgb255 200 200 200)
        , Font.color (rgb255 0 0 0)
        , Border.rounded 5
        , padding 10
        , width fill
        , Events.onClick (AddRoleButtonClick name)
        ]
        (text name)


roleList : Model -> Element Msg
roleList model =
    let
        specialCards =
            Dict.values (Dict.map (roleDescription model) model.selected)

        villagerCount =
            playerCount model - cardCount model

        additionalVillagers =
            roleDescriptionClosed "Dorfbewohner" { newCard | count = villagerCount }

        allCards =
            if villagerCount < 0 then
                List.append specialCards [ playerLimitBreached (playerCount model) (cardCount model) ]

            else if villagerCount == 0 then
                specialCards

            else
                List.append specialCards [ additionalVillagers ]
    in
    Element.column [ spacing 10, width fill ] <|
        allCards


roleDescription : Model -> String -> CardInformation -> Element Msg
roleDescription model name count =
    if model.openCard == Just name then
        cardOpenView model name count

    else
        roleDescriptionClosed name count


roleDescriptionClosed : String -> CardInformation -> Element Msg
roleDescriptionClosed name cardInfo =
    el
        [ Font.color (rgb255 0 0 0)
        , Border.rounded 5
        , Border.color (rgb255 0 0 0)
        , Border.width 1
        , padding 10
        , width fill
        ]
    <|
        Element.row
            [ spacing 5 ]
            [ text <| String.fromInt cardInfo.count, roleDescriptionLabelClosed name, removeCardButton name ]


roleDescriptionLabelClosed : String -> Element Msg
roleDescriptionLabelClosed name =
    el [ Events.onClick (SelectCard name) ] (text name)


roleDescriptionLabelOpened : String -> Element Msg
roleDescriptionLabelOpened name =
    el [ Events.onClick CloseCard ] (text name)


removeCardButton : String -> Element Msg
removeCardButton template =
    el
        [ alignRight
        , Events.onClick (RemoveRoleButtonClick template)
        , Background.color (rgb255 255 200 200)
        ]
        (text "x")


cardOpenView : Model -> String -> CardInformation -> Element Msg
cardOpenView model name cardInfo =
    Element.column
        [ Border.rounded 5
        , Border.color (rgb255 0 0 0)
        , Border.width 1
        , width fill
        ]
        [ cardHeaderOpen model name cardInfo
        , cardContent model name cardInfo
        ]


cardHeaderOpen : Model -> String -> CardInformation -> Element Msg
cardHeaderOpen model name cardInfo =
    el
        [ Font.color (rgb255 0 0 0)
        , Font.bold
        , padding 10
        , width fill
        ]
    <|
        Element.row
            [ spacing 5 ]
            [ text <| String.fromInt cardInfo.count, roleDescriptionLabelOpened name, removeCardButton name ]


cardContent : Model -> String -> CardInformation -> Element Msg
cardContent model name cardInfo =
    Element.column
        [ Background.color (rgb255 230 230 230)
        , width fill
        , height fill
        , padding 10
        ]
        [ text "Spielerauswahl"
        , playerCardSelection model name cardInfo
        ]


playerCardSelection : Model -> String -> CardInformation -> Element Msg
playerCardSelection model name cardInfo =
    model.players
        |> List.map (playerSelector model name cardInfo)
        |> Element.wrappedRow [ spacing 5 ]


playerSelector : Model -> String -> CardInformation -> String -> Element Msg
playerSelector model cardName cardInfo playerName =
    let
        isAlreadySelected =
            Set.member playerName cardInfo.players
    in
    if isAlreadySelected then
        el
            [ Border.rounded 5
            , padding 7
            , Background.color (rgb255 200 200 200)
            , Events.onClick (RemovePlayerFromRole cardName playerName)
            ]
            (text playerName)

    else
        el
            [ Border.rounded 5
            , padding 7
            , Border.color (rgb255 200 200 200)
            , Border.width 1
            , Events.onClick (AssignPlayerToRole cardName playerName)
            ]
            (text playerName)


playerLimitBreached : Int -> Int -> Element msg
playerLimitBreached expected actual =
    el
        [ Font.color (rgb255 0 0 0)
        , Border.rounded 5
        , Border.color (rgb255 0 0 0)
        , Border.width 1
        , padding 10
        , width fill
        ]
        (text <|
            "Achtung, du hast "
                ++ String.fromInt actual
                ++ " Karten auf "
                ++ String.fromInt expected
                ++ " Spieler verteilt!"
        )
