using System;
using Xunit;
using JMeterCircleCI;

namespace JMeterCircleCI.Tests
{
    public class PaymentService_ValidatePaymentTransaction
    {
        [Fact]
        public void IsTransactionCompleted()
        {
            var paymentService = new PaymentService();
            bool result = paymentService.IsCompleted(true);

            Assert.True(result, "Transaction should be completed");
        }

        [Fact]
        public void IsTransactionNotCompleted()
        {
            var paymentService = new PaymentService();
            bool result = paymentService.IsCompleted(false);

            Assert.False(result, "Transaction should not be completed");
        }
    }
}
