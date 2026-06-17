package temps

import org.apache.spark.rdd.RDD
import utils.SparkProgramTemplate

/**
 * Count above-freezing readings per weather station.
 *
 *   input1 = readings.csv : station, celsius
 *
 * Exercises field parsing (toInt / isInteger paths), a numeric filter on the
 * parsed value, and reduceByKey counting. A deliberately simple program useful
 * for inspecting the crash-inducing (non-integer celsius) terminating paths.
 */
object temps extends SparkProgramTemplate {
  def main(args: Array[String]): Unit = {}

  override def execute(input1: RDD[String]): RDD[String] = {
    input1
      .filter(r => r.split(",")(1).toInt > 0)
      .map(r => (r.split(",")(0), 1))
      .reduceByKey(_ + _)
      .map(t => t._1 + ":" + t._2)
  }
}
