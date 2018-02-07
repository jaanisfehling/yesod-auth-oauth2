{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE TypeFamilies #-}

-- |
--
-- This single-file Yesod app uses all plugins defined within this site, as a
-- means of manual verification that they work. When adding a new plugin, add
-- usage of it here and verify locally that it works.
--
-- To do so, see @.env.example@, then:
--
-- > stack build --flag yesod-auth-oauth2:example
-- > stack exec yesod-auth-oauth2-example
-- >
-- > $BROWSER http://localhost:3000
--
module Main where

import Data.Monoid ((<>))
import Data.Text (Text)
import qualified Data.Text as T
import LoadEnv
import Network.HTTP.Conduit
import Network.Wai.Handler.Warp (runEnv)
import System.Environment (getEnv)
import Yesod
import Yesod.Auth
import Yesod.Auth.OAuth2.BattleNet
import Yesod.Auth.OAuth2.Bitbucket
import Yesod.Auth.OAuth2.EveOnline
import Yesod.Auth.OAuth2.Github
import Yesod.Auth.OAuth2.Google
import Yesod.Auth.OAuth2.Nylas
import Yesod.Auth.OAuth2.Salesforce
import Yesod.Auth.OAuth2.Slack
import Yesod.Auth.OAuth2.Spotify
import Yesod.Auth.OAuth2.Upcase

data App = App
    { appHttpManager :: Manager
    , appAuthPlugins :: [AuthPlugin App]
    }

mkYesod "App" [parseRoutes|
    / RootR GET
    /auth AuthR Auth getAuth
|]

instance Yesod App where
    -- see https://github.com/thoughtbot/yesod-auth-oauth2/issues/87
    approot = ApprootStatic "http://localhost:3000"

instance YesodAuth App where
    type AuthId App = Text
    loginDest _ = RootR
    logoutDest _ = RootR

    -- Disable any attempt to read persisted authenticated state
    maybeAuthId = return Nothing

    -- Copy the Creds response into the session for viewing after
    authenticate c = do
        mapM_ (uncurry setSession) $
            [ ("credsIdent", credsIdent c)
            , ("credsPlugin", credsPlugin c)
            ] ++ credsExtra c

        return $ Authenticated "1"

    authHttpManager = appHttpManager
    authPlugins = appAuthPlugins

instance RenderMessage App FormMessage where
    renderMessage _ _ = defaultFormMessage

getRootR :: Handler Html
getRootR = do
    sess <- getSession

    defaultLayout [whamlet|
        <h1>Yesod Auth OAuth2 Example
        <h2>
            <a href=@{AuthR LoginR}>Log in
        <h2>Session Information
        <pre style="word-wrap: break-word;">
            #{show sess}
    |]

mkFoundation :: IO App
mkFoundation = do
    loadEnv

    appHttpManager <- newManager tlsManagerSettings
    appAuthPlugins <- sequence
        -- When Providers are added, add them here and update .env.example.
        -- Nothing else should need changing.
        --
        -- FIXME: oauth2BattleNet is quite annoying!
        --
        [ loadPlugin (oauth2BattleNet [whamlet|TODO|] "en") "BATTLE_NET"
        , loadPlugin oauth2Bitbucket "BITBUCKET"
        , loadPlugin (oauth2Eve Plain) "EVE_ONLINE"
        , loadPlugin oauth2Github "GITHUB"
        , loadPlugin oauth2Google "GOOGLE"
        , loadPlugin oauth2Nylas "NYLAS"
        , loadPlugin oauth2Salesforce "SALES_FORCE"
        , loadPlugin oauth2Slack "SLACK"
        , loadPlugin (oauth2Spotify []) "SPOTIFY"
        , loadPlugin oauth2Upcase "UPCASE"
        ]

    return App{..}
  where
    loadPlugin f prefix = do
        clientId <- getEnv $ prefix <> "_CLIENT_ID"
        clientSecret <- getEnv $ prefix <> "_CLIENT_SECRET"
        pure $ f (T.pack clientId) (T.pack clientSecret)

main :: IO ()
main = runEnv 3000 =<< toWaiApp =<< mkFoundation