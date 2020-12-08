module Game.Asteroids.World.Timer(
    Timer(..)
  , initTimer
  , getDelta
  , setDelta
  ) where

import Control.Monad.IO.Class
import Kecsik
import System.Clock

-- | Holds time passed since previous tick
data Timer = Timer {
    timerOld   :: !TimeSpec
  , timerDelta :: !Float
  } deriving (Show, Generic)

instance Mutable s TimeSpec

instance Mutable s Timer where
  type Ref s Timer = GRef s Timer

instance Component s Timer where
  type Storage s Timer = Global s Timer

instance Default Timer where
  def = Timer 0 0

initTimer :: (MonadIO m, Has w m Timer) => SystemT w m ()
initTimer = do
  t0 <- liftIO $ getTime Monotonic
  set global $ Timer t0 0

getDelta :: (MonadIO m, Has w m Timer) => SystemT w m Float
getDelta = maybe 0 timerDelta <$> get global

deltaTime :: TimeSpec -> TimeSpec -> Float
deltaTime t1 t2 = (/ 1000000000) $ fromIntegral $ toNanoSecs $ diffTimeSpec t1 t2

setDelta :: (MonadIO m, Has w m Timer) => TimeSpec -> SystemT w m ()
setDelta t2 = modify global $ \(Timer t1 _) -> Timer t2 (deltaTime t2 t1)
