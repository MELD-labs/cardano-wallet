{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE NumericUnderscores #-}
{-# LANGUAGE OverloadedLabels #-}
{-# LANGUAGE OverloadedLists #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeApplications #-}

module Cardano.Wallet.Primitive.MigrationSpec
    where

import Prelude

import Cardano.Wallet.Primitive.Migration
    ( CategorizedUTxO (..)
    , MigrationPlan (..)
    , RewardBalance (..)
    , UTxOEntryCategory (..)
    , addValueToOutputs
    , categorizeUTxOEntries
    , categorizeUTxOEntry
    , createPlan
    , uncategorizeUTxOEntries
    )
import Cardano.Wallet.Primitive.Migration.Selection
    ( Selection (..) )
import Cardano.Wallet.Primitive.Migration.SelectionSpec
    ( MockInputId
    , MockTxConstraints (..)
    , conjoinMap
    , counterexampleMap
    , genCoinRange
    , genMockInput
    , genMockInputAdaOnly
    , genMockTxConstraints
    , genTokenBundleMixed
    , genTokenMap
    , unMockTxConstraints
    )
import Cardano.Wallet.Primitive.Types.Coin
    ( Coin (..) )
import Cardano.Wallet.Primitive.Types.TokenBundle
    ( TokenBundle (..) )
import Cardano.Wallet.Primitive.Types.TokenMap
    ( TokenMap )
import Cardano.Wallet.Primitive.Types.Tx
    ( TxConstraints, txOutputHasValidSize, txOutputHasValidTokenQuantities )
import Control.Monad
    ( replicateM )
import Data.Either
    ( isLeft, isRight )
import Data.Generics.Internal.VL.Lens
    ( view )
import Data.Generics.Labels
    ()
import Data.List.NonEmpty
    ( NonEmpty (..) )
import Data.Set
    ( Set )
import Fmt
    ( padLeftF, pretty )
import Test.Hspec
    ( Spec, describe, it )
import Test.Hspec.Core.QuickCheck
    ( modifyMaxSuccess )
import Test.Hspec.Extra
    ( parallel )
import Test.QuickCheck
    ( Arbitrary (..)
    , Blind (..)
    , Gen
    , Property
    , checkCoverage
    , choose
    , counterexample
    , cover
    , label
    , oneof
    , property
    , withMaxSuccess
    )

import qualified Cardano.Wallet.Primitive.Migration.Selection as Selection
import qualified Data.Foldable as F
import qualified Data.List as L
import qualified Data.List.NonEmpty as NE
import qualified Data.Set as Set

spec :: Spec
spec = describe "Cardano.Wallet.Primitive.MigrationSpec" $

    modifyMaxSuccess (const 1000) $ do

    parallel $ describe "Creating migration plans" $ do

        it "prop_createPlan_small" $
            property prop_createPlan_small
        it "prop_createPlan_large" $
            property prop_createPlan_large
        it "prop_createPlan_giant" $
            property prop_createPlan_giant

    parallel $ describe "Categorizing UTxO entries" $ do

        it "prop_categorizeUTxOEntry" $
            property prop_categorizeUTxOEntry

    parallel $ describe "Adding value to outputs" $ do

        it "prop_addValueToOutputs" $
            property prop_addValueToOutputs

--------------------------------------------------------------------------------
-- Creating migration plans
--------------------------------------------------------------------------------

data ArgsForCreatePlan = ArgsForCreatePlan
    { mockConstraints :: MockTxConstraints
    , mockInputs :: [(MockInputId, TokenBundle)]
    , mockRewardBalance :: Coin
    }
    deriving (Eq, Show)

newtype Small a = Small { unSmall :: a }
    deriving (Eq, Show)

newtype Large a = Large { unLarge :: a }
    deriving (Eq, Show)

newtype Giant a = Giant { unGiant :: a }
    deriving (Eq, Show)

instance Arbitrary (Small ArgsForCreatePlan) where
    arbitrary = Small <$> genArgsForCreatePlan
        (0, 100) genMockInput

instance Arbitrary (Large ArgsForCreatePlan) where
    arbitrary = Large <$> genArgsForCreatePlan
        (1_000, 1_000) genMockInput

instance Arbitrary (Giant ArgsForCreatePlan) where
    arbitrary = Giant <$> genArgsForCreatePlan
        (100_000, 100_000) genMockInputAdaOnly

prop_createPlan_small :: Blind (Small ArgsForCreatePlan) -> Property
prop_createPlan_small (Blind (Small args)) =
    withMaxSuccess 1000 $
    prop_createPlan args

prop_createPlan_large :: Blind (Large ArgsForCreatePlan) -> Property
prop_createPlan_large (Blind (Large args)) =
    withMaxSuccess 100 $
    prop_createPlan args

prop_createPlan_giant :: Blind (Giant ArgsForCreatePlan) -> Property
prop_createPlan_giant (Blind (Giant args)) =
    withMaxSuccess 1 $
    prop_createPlan args

genArgsForCreatePlan
    :: (Int, Int)
    -- ^ Input count range
    -> (MockTxConstraints -> Gen (MockInputId, TokenBundle))
    -- ^ Genenator for inputs
    -> Gen ArgsForCreatePlan
genArgsForCreatePlan (inputCountMin, inputCountMax) genInput = do
    mockConstraints <- genMockTxConstraints
    mockInputCount <- choose (inputCountMin, inputCountMax)
    mockInputs <- replicateM mockInputCount (genInput mockConstraints)
    mockRewardBalance <- oneof
        [ pure (Coin 0)
        , genCoinRange (Coin 1) (Coin 1_000_000)
        ]
    pure ArgsForCreatePlan
        { mockConstraints
        , mockInputs
        , mockRewardBalance
        }

prop_createPlan :: ArgsForCreatePlan -> Property
prop_createPlan mockArgs =
    label labelTransactionCount $
    label labelMeanTransactionInputCount $
    label labelMeanTransactionOutputCount $
    label (labelNotSelectedPercentage "freeriders" freeriders) $
    label (labelNotSelectedPercentage "supporters" supporters) $
    label (labelNotSelectedPercentage "ignorables" ignorables) $

    counterexample counterexampleText $
    conjoinMap
        [ ( "inputs are not preserved"
          , inputIds == inputIdsSelected `Set.union` inputIdsNotSelected )
        , ( "total fee is incorrect"
          , totalFee result == totalFeeExpected )
        , ( "more than one transaction has reward withdrawal"
            -- TODO
          , True )
        , ( "reward withdrawal amount incorrect"
            -- TODO
          , True )
        , ( "reward withdrawal missing"
            -- TODO
          , True )
        , ( "asset balance not preserved"
            -- TODO
          , True )
        , ( "one or more supporters not selected"
          , supporters (unselected result) == [] )
        , ( "one or more transactions is incorrect"
            --TODO: check the SelectionCorrectness
          , True )
        ]
  where
    labelTransactionCount = pretty $ mconcat
        [ "number of transactions required: "
        , padLeftF 3 ' ' (10 * selectionCountDiv10)
        , " – "
        , padLeftF 3 ' ' (10 * (selectionCountDiv10 + 1) - 1)
        ]
      where
        selectionCountDiv10 = selectionCount `div` 10

    labelMeanTransactionInputCount = pretty $ mconcat
        [ "mean number of inputs per transaction: "
        , padLeftF 3 ' ' (10 * meanTxInputCountDiv10)
        , " – "
        , padLeftF 3 ' ' (10 * (meanTxInputCountDiv10 + 1) - 1)
        ]
      where
        meanTxInputCountDiv10 = meanTxInputCount `div` 10
        meanTxInputCount :: Int
        meanTxInputCount
            | selectionCount == 0 =
                0
            | otherwise =
                totalSelectedInputCount `div` selectionCount
        totalSelectedInputCount :: Int
        totalSelectedInputCount =
            L.sum $ L.length . view #inputIds <$> selections result

    labelMeanTransactionOutputCount = pretty $ mconcat
        [ "mean number of outputs per transaction: "
        , padLeftF 3 ' ' meanTxOutputCount
        ]
      where
        meanTxOutputCount :: Int
        meanTxOutputCount
            | selectionCount == 0 =
                0
            | otherwise =
                totalSelectedOutputCount `div` selectionCount
        totalSelectedOutputCount :: Int
        totalSelectedOutputCount =
            L.sum $ L.length . view #outputs <$> selections result

    labelNotSelectedPercentage categoryName category = pretty $ mconcat
        [ categoryName
        , " not selected: "
        , padLeftF 3 ' ' percentage
        , "%"
        ]
      where
        percentage
            | entriesAvailable == 0 =
                0
            | otherwise =
                (entriesNotSelected * 100) `div` entriesAvailable

        entriesAvailable :: Int
        entriesAvailable = length $ category categorizedUTxO
        entriesNotSelected :: Int
        entriesNotSelected = length $ category $ unselected result

    ArgsForCreatePlan
        { mockConstraints
        , mockInputs
        , mockRewardBalance
        } = mockArgs

    constraints = unMockTxConstraints mockConstraints
    result = createPlan constraints categorizedUTxO
        (RewardBalance mockRewardBalance)

    categorizedUTxO = categorizeUTxOEntries constraints mockInputs

    inputIds :: Set MockInputId
    inputIds = Set.fromList (fst <$> mockInputs)

    inputIdsSelected :: Set MockInputId
    inputIdsSelected = Set.fromList
        [ i
        | s <- selections result
        , i <- NE.toList (view #inputIds s)
        ]

    inputIdsNotSelected :: Set MockInputId
    inputIdsNotSelected = Set.fromList
        $ fmap fst
        $ uncategorizeUTxOEntries
        $ unselected result

    selectionCount = length (selections result)

    totalFeeExpected :: Coin
    totalFeeExpected = F.foldMap fee (selections result)

    counterexampleText = counterexampleMap
        [ ( "mockConstraints"
          , show mockConstraints )
        , ( "count of supporters available"
          , show (length $ supporters categorizedUTxO) )
        , ( "count of supporters not selected"
          , show (length $ supporters $ unselected result) )
        , ( "count of freeriders available"
          , show (length $ freeriders categorizedUTxO) )
        , ( "count of freeriders not selected"
          , show (length $ freeriders $ unselected result) )
        , ( "count of ignorables available"
          , show (length $ ignorables categorizedUTxO) )
        , ( "count of ignorables not selected"
          , show (length $ ignorables $ unselected result) )
        ]

--------------------------------------------------------------------------------
-- Categorizing UTxO entries
--------------------------------------------------------------------------------

data ArgsForCategorizeUTxOEntry = ArgsForCategorizeUTxOEntry
    { mockConstraints :: MockTxConstraints
    , mockEntry :: TokenBundle
    }
    deriving (Eq, Show)

instance Arbitrary ArgsForCategorizeUTxOEntry where
    arbitrary = genArgsForCategorizeUTxOEntry

genArgsForCategorizeUTxOEntry :: Gen ArgsForCategorizeUTxOEntry
genArgsForCategorizeUTxOEntry = do
    mockConstraints <- genMockTxConstraints
    mockEntry <- genTokenBundleMixed mockConstraints
    pure ArgsForCategorizeUTxOEntry {..}

prop_categorizeUTxOEntry :: ArgsForCategorizeUTxOEntry -> Property
prop_categorizeUTxOEntry mockArgs =
    checkCoverage $
    cover 5 (result == Supporter) "Supporter" $
    cover 5 (result == Freerider) "Freerider" $
    cover 5 (result == Ignorable) "Ignorable" $
    property
        $ selectionCreateExpectation
        $ Selection.create
            constraints (Coin 0) mockEntry [()] [view #tokens mockEntry]
  where
    ArgsForCategorizeUTxOEntry
        { mockConstraints
        , mockEntry
        } = mockArgs
    constraints = unMockTxConstraints mockConstraints
    result = categorizeUTxOEntry constraints mockEntry
    selectionCreateExpectation = case result of
        Supporter -> isRight
        Freerider -> isLeft
        Ignorable -> isLeft

--------------------------------------------------------------------------------
-- Adding value to outputs
--------------------------------------------------------------------------------

data ArgsForAddValueToOutputs = ArgsForAddValueToOutputs
    { mockConstraints :: MockTxConstraints
    , mockOutputs :: NonEmpty TokenMap
    }

instance Arbitrary ArgsForAddValueToOutputs where
    arbitrary = genArgsForAddValueToOutputs

genArgsForAddValueToOutputs :: Gen ArgsForAddValueToOutputs
genArgsForAddValueToOutputs = do
    mockConstraints <- genMockTxConstraints
    -- The upper limit is chosen to be comfortably greater than the maximum
    -- number of inputs we can typically fit into a transaction:
    mockOutputCount <- choose (1, 128)
    mockOutputs <- (:|)
        <$> genTokenMap mockConstraints
        <*> replicateM (mockOutputCount - 1) (genTokenMap mockConstraints)
    pure ArgsForAddValueToOutputs {..}

prop_addValueToOutputs :: Blind ArgsForAddValueToOutputs -> Property
prop_addValueToOutputs mockArgs =
    withMaxSuccess 100 $
    conjoinMap
        [ ( "Value is preserved"
          , F.fold result == F.fold mockOutputs )
        , ( "All outputs have valid sizes (if ada maximized)"
          , all (txOutputHasValidSizeWithMaxAda constraints) result )
        , ( "All outputs have valid token quantities"
          , all (txOutputHasValidTokenQuantities constraints) result )
        ]
  where
    Blind ArgsForAddValueToOutputs
        { mockConstraints
        , mockOutputs
        } = mockArgs
    constraints = unMockTxConstraints mockConstraints
    result :: NonEmpty TokenMap
    result = F.foldl'
        (addValueToOutputs constraints . NE.toList)
        (addValueToOutputs constraints [] (NE.head mockOutputs))
        (NE.tail mockOutputs)

txOutputHasValidSizeWithMaxAda
    :: Ord s => TxConstraints s -> TokenMap -> Bool
txOutputHasValidSizeWithMaxAda constraints b =
    txOutputHasValidSize constraints $ TokenBundle maxBound b

--------------------------------------------------------------------------------
-- Miscellaneous types and functions
--------------------------------------------------------------------------------

coinToInteger :: Coin -> Integer
coinToInteger = fromIntegral . unCoin
