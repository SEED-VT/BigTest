package sales

import org.apache.spark.rdd.RDD
import utils.SparkProgramTemplate

/**
 * Total revenue per product category, counting only high-value orders.
 *
 *   input1 = orders.csv   : orderId, productId, amount
 *   input2 = products.csv : productId, category
 *
 * Exercises a relational join keyed on productId, a numeric filter (amount > 100,
 * with the toInt parse/isInteger paths), and reduceByKey summation of amounts.
 */
object sales extends SparkProgramTemplate {
  def main(args: Array[String]): Unit = {}

  override def execute(input1: RDD[String], input2: RDD[String]): RDD[String] = {
    val orders = input1
      .filter(o => o.split(",")(2).toInt > 100)
      .map(o => (o.split(",")(1), o.split(",")(2).toInt)) // productId -> amount

    val products = input2
      .map(p => (p.split(",")(0), p.split(",")(1)))        // productId -> category

    orders
      .join(products)
      .map(j => {
        // count orders per category, split into big/small tiers. Both joined
        // fields are used in a typed op (comparison / concat) so BigTest can
        // infer their types.
        if (j._2._1 > 500) (j._2._2.concat(":big"), 1)
        else (j._2._2.concat(":small"), 1)
      })
      .reduceByKey(_ + _)
      .map(t => t._1 + ":" + t._2)
  }
}
