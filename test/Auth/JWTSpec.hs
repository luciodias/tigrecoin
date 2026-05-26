{-# LANGUAGE OverloadedStrings #-}

module Auth.JWTSpec (spec) where

import Test.Hspec
import Test.QuickCheck

import Auth.JWT (AuthClaims(..), makeToken, verifyToken)
import Control.Monad.IO.Class (liftIO)
import Data.Either (isLeft)

import qualified Data.ByteString.Char8 as C
import qualified Data.Text as T

instance Eq AuthClaims where
  (==) (AuthClaims u1 r1) (AuthClaims u2 r2) = u1 == u2 && r1 == r2

instance Show AuthClaims where
  show (AuthClaims u r) = "AuthClaims { acUserId = " <> T.unpack u <> ", acRole = " <> T.unpack r <> " }"

spec :: Spec
spec = do
  describe "makeToken / verifyToken roundtrip" $ do
    it "round-trips valid claims" $ do
      let secret = "secret-key"
          claims = AuthClaims "user-1" "user"
      token <- makeToken secret 3600 claims
      verifyToken secret token `shouldBe` Right claims

    it "fails with wrong secret" $ do
      let secret = "secret-key"
          wrong  = "wrong-key"
          claims = AuthClaims "user-1" "user"
      token <- makeToken secret 3600 claims
      verifyToken wrong token `shouldBe` Left "Signature verification failed"

    it "fails with malformed token" $ do
      verifyToken "secret" "not-a-valid-token" `shouldBe` Left "Invalid JWT format"

    it "fails with tampered payload" $ do
      let secret = "secret-key"
          claims = AuthClaims "user-1" "user"
      token <- makeToken secret 3600 claims
      let parts = C.split '.' token
      case parts of
        [h, _, s] -> do
          let tamperedPayload = "eyJzdWIiOiJ1c2VyLTIiLCJyb2xlIjoidXNlciJ9"
              tampered = h <> "." <> tamperedPayload <> "." <> s
          verifyToken secret tampered `shouldSatisfy` isLeft
        _ -> expectationFailure "Token does not have 3 parts"

    it "succeeds with admin role" $ do
      let secret = "admin-secret"
          claims = AuthClaims "admin-1" "admin"
      token <- makeToken secret 3600 claims
      case verifyToken secret token of
        Right c -> do
          acUserId c `shouldBe` "admin-1"
          acRole c `shouldBe` "admin"
        Left e -> expectationFailure $ "verify failed: " <> T.unpack e

    it "succeeds with arbitrary Text in sub/role" $ do
      let secret = "complex-secret"
          claims = AuthClaims "user-42" "moderator"
      token <- makeToken secret 3600 claims
      verifyToken secret token `shouldBe` Right claims

  describe "QuickCheck properties" $ do
    it "verifyToken fails with wrong secret" $
      property $ \claims -> ioProperty $ do
        token <- liftIO $ makeToken "correct-secret" 3600 claims
        let verdict = verifyToken "wrong-secret" token
        pure $ isLeft verdict

    it "verifyToken fails with tampered token" $
      property $ \claims -> ioProperty $ do
        token <- liftIO $ makeToken "secret" 3600 claims
        let parts = C.split '.' token
        case parts of
          [h, _, s] -> do
            let tampered = h <> "." <> "aW52YWxpZA" <> "." <> s
            pure $ isLeft $ verifyToken "secret" tampered
          _ -> pure False

    it "empty claims round-trip" $
      property $ ioProperty $ do
        token <- liftIO $ makeToken "secret" 3600 (AuthClaims "" "")
        let result = verifyToken "secret" token
        pure $ case result of
          Right c -> c == AuthClaims "" ""
          Left  _ -> False

instance Arbitrary AuthClaims where
  arbitrary = AuthClaims
    <$> (T.pack <$> listOf1 (elements (['a'..'z'] <> ['0'..'9'])))
    <*> elements ["user", "admin", "moderator"]
