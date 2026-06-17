package credit

import org.apache.spark.rdd.RDD
import org.apache.spark.{SparkConf, SparkContext}
import utils.SparkRDDGenerator

object credit extends SparkRDDGenerator {
  def main(args: Array[String]): Unit = {
  }
  override def execute(input1: RDD[String], input2: RDD[String]): RDD[String] = {
    val personal = input1.map(s => (s.split(",")(0), s.split(",")(3)))
    val bank = input2.filter(s => s.split(",")(1).equals("bad")).map(s => (s.split(",")(0), s.split(",")(4)))
    personal.join(bank).map(s => s._2._1 + "," + s._2._2)
  }
}
