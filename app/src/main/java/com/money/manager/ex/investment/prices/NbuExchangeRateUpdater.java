package com.money.manager.ex.investment.prices;

import android.content.Context;
import android.widget.Toast;

import com.google.gson.Gson;
import com.google.gson.GsonBuilder;
import com.google.gson.annotations.SerializedName;
import com.money.manager.ex.MmexApplication;
import com.money.manager.ex.R;
import com.money.manager.ex.core.UIHelper;
import com.money.manager.ex.investment.SecurityPriceModel;
import com.money.manager.ex.investment.events.PriceDownloadedEvent;

import org.greenrobot.eventbus.EventBus;

import java.util.ArrayList;
import java.util.Date;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import javax.inject.Inject;

import info.javaperformance.money.MoneyFactory;
import okhttp3.OkHttpClient;
import retrofit2.Call;
import retrofit2.Callback;
import retrofit2.Response;
import retrofit2.Retrofit;
import retrofit2.converter.gson.GsonConverterFactory;
import retrofit2.http.GET;
import retrofit2.http.Query;
import timber.log.Timber;

/**
 * Gets exchange rates from the National Bank of Ukraine API.
 * NBU API returns exchange rates based on UAH currency.
 */

public class NbuExchangeRateUpdater extends PriceUpdaterBase implements IExchangeRateUpdater {

    private static final String TAG = NbuExchangeRateUpdater.class.getSimpleName();

    private final static String NBU_BASE_CURRENCY = "UAH";

    @Inject
    OkHttpClient okHttpClient;

    public NbuExchangeRateUpdater(Context context) {
        super(context);
        MmexApplication.getApp().iocComponent.inject(this);
    }

    @Override
    public void downloadPrices(final String baseCurrency, final List<String> symbols) {

        if (symbols == null || symbols.size() == 0) return;
        showProgressDialog(symbols.size());

        ApiService service = getService();

        Callback<List<ExchangeRate>> callback = new Callback<List<ExchangeRate>>() {

            @Override
            public void onResponse(Call<List<ExchangeRate>> call, Response<List<ExchangeRate>> response) {
                onContentDownloaded(baseCurrency, symbols, response.body());
            }

            @Override
            public void onFailure(Call<List<ExchangeRate>> call, Throwable t) {
                closeProgressDialog();
                Timber.e(t, "fetching price");
            }
        };

        service.getAllAvailableExchangeRates().enqueue(callback);

    }

    private void onContentDownloaded(String baseCurrency, List<String> requestedCurrencies, List<ExchangeRate> exchangeRates) {
        UIHelper uiHelper = new UIHelper(getContext());

        if (exchangeRates == null || exchangeRates.size() == 0) {
            uiHelper.showToast(R.string.error_updating_rates);
            closeProgressDialog();
            return;
        }

        Map<String, ExchangeRate> receivedExchangeRatesMap = new HashMap<>();
        for (ExchangeRate rate : exchangeRates) {
            receivedExchangeRatesMap.put(rate.symbol, rate);
        }

        List<SecurityPriceModel> fetchedModels = new ArrayList<>();
        for (String requestedCurrency : requestedCurrencies) {
            ExchangeRate rate;
            if (NBU_BASE_CURRENCY.equals(requestedCurrency)) {
                rate = new ExchangeRate(1, NBU_BASE_CURRENCY, new Date());
            } else {
                rate = receivedExchangeRatesMap.get(requestedCurrency);
            }
            if (rate == null) continue;
            fetchedModels.add(rate.convertToSecurityPriceModel());
        }

        if (!NBU_BASE_CURRENCY.equals(baseCurrency)) {

            if (receivedExchangeRatesMap.containsKey(baseCurrency)) {
                ExchangeRate baseRate = receivedExchangeRatesMap.get(baseCurrency);
                if (baseRate != null) {
                    SecurityPriceModel baseModel = baseRate.convertToSecurityPriceModel();
                    fetchedModels = updateRatesWithAnotherBase(baseModel, fetchedModels);
                }
            }

        }

        fetchedModels.add(
                new ExchangeRate(1, baseCurrency, new Date()).convertToSecurityPriceModel());

        StringBuilder updatedCurrencies = new StringBuilder();
        postDownloadedRates(fetchedModels, updatedCurrencies);
        
        closeProgressDialog();
        // Notify the user of the prices that have been downloaded.
        String message = getContext().getString(R.string.download_complete) +
                " (" + updatedCurrencies.toString() + ")";
        uiHelper.showToast(message, Toast.LENGTH_LONG);
    }

    private void postDownloadedRates(List<SecurityPriceModel> requestedCurrencies, StringBuilder updatedCurrencies) {
        for (SecurityPriceModel model : requestedCurrencies) {
            EventBus.getDefault().post(new PriceDownloadedEvent(model.symbol, model.price, model.date));
            updatedCurrencies.append(model.symbol).append(",");
        }
        updatedCurrencies.deleteCharAt(updatedCurrencies.lastIndexOf(","));
    }

    private List<SecurityPriceModel> updateRatesWithAnotherBase(SecurityPriceModel baseCurrency,
                                                                List<SecurityPriceModel> exchangeRates) {
        for (SecurityPriceModel model : exchangeRates) {
            model.price = model.price.divide(baseCurrency.price.toDouble(), 8);
        }
        return exchangeRates;
    }

    private ApiService getService() {
        String BASE_URL = "https://bank.gov.ua/NBUStatService/v1/statdirectory/";
        Gson gson = new GsonBuilder()
                .setDateFormat("dd.MM.yyyy")
                .create();
        Retrofit retrofit = new Retrofit.Builder()
                .baseUrl(BASE_URL)
                .client(okHttpClient)
                .addConverterFactory(GsonConverterFactory.create(gson))
                .build();

        return retrofit.create(ApiService.class);
    }

    private interface ApiService {
        /**
         * Gets exchange rate for a currency to UAH
         * @param baseCurrency
         * @return
         */
        @GET("exchange?json")
        Call<List<ExchangeRate>> getExchangeRate(@Query("valcode") String baseCurrency);

        @GET("exchange?json")
        Call<List<ExchangeRate>> getAllAvailableExchangeRates();
    }

    private class ExchangeRate {

        @SerializedName("rate")
        double rate;

        @SerializedName("cc")
        String symbol;

        @SerializedName("exchangedate")
        Date date;

        ExchangeRate() {}

        ExchangeRate(double rate, String symbol, Date date) {
            this.rate = rate;
            this.symbol = symbol;
            this.date = date;
        }

        SecurityPriceModel convertToSecurityPriceModel() {
            
            SecurityPriceModel model = new SecurityPriceModel();
            model.date = date;
            model.price = MoneyFactory.fromDouble(rate);
            model.symbol = symbol;

            return model;
        }

        @Override
        public String toString() {
            return "ExchangeRate{" +
                    "rate=" + rate +
                    ", symbol='" + symbol + '\'' +
                    '}';
        }
    }
}
