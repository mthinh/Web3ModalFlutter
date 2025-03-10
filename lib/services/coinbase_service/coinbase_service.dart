import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:web3modal_flutter/services/coinbase_service/i_coinbase_service.dart';
import 'package:web3modal_flutter/services/coinbase_service/models/coinbase_events.dart';
import 'package:web3modal_flutter/web3modal_flutter.dart';

import 'package:coinbase_wallet_sdk/currency.dart';
import 'package:coinbase_wallet_sdk/action.dart';
import 'package:coinbase_wallet_sdk/coinbase_wallet_sdk.dart';
import 'package:coinbase_wallet_sdk/configuration.dart';
import 'package:coinbase_wallet_sdk/eth_web3_rpc.dart';
import 'package:coinbase_wallet_sdk/request.dart';

import 'models/coinbase_data.dart';

class CoinbaseService implements ICoinbaseService {
  static const coinbaseWalletId =
      'fd20dc426fb37566d803205b19bbc1d4096b248ac04548e3cfb6b3a38bd033aa';
  static const coinbaseSchema = 'cbwallet://wsegue';

  static const supportedMethods = [
    'personal_sign',
    'eth_sendTransaction',
    'eth_requestAccounts',
    'eth_signTypedData_v3',
    'eth_signTypedData_v4',
    'eth_signTransaction',
    'wallet_switchEthereumChain',
    'wallet_addEthereumChain',
    'wallet_watchAsset',
  ];

  @override
  Event<CoinbaseConnectEvent> onCoinbaseConnect = Event<CoinbaseConnectEvent>();

  @override
  Event<CoinbaseErrorEvent> onCoinbaseError = Event<CoinbaseErrorEvent>();

  @override
  Event<CoinbaseSessionEvent> onCoinbaseSessionUpdate =
      Event<CoinbaseSessionEvent>();

  @override
  Event<CoinbaseResponseEvent> get onCoinbaseResponse =>
      Event<CoinbaseResponseEvent>();

  @protected
  @override
  Future<void> cbInit({
    required PairingMetadata metadata,
    W3MWalletInfo? cbWallet,
  }) async {
    // Configure SDK for each platform
    final universal = metadata.redirect?.universal ?? metadata.url;
    final nativeLink = metadata.redirect?.native ?? '';
    if (universal.isNotEmpty && nativeLink.isNotEmpty) {
      try {
        final config = Configuration(
          ios: IOSConfiguration(
            host: Uri.parse(cbWallet?.listing.mobileLink ?? coinbaseSchema),
            callback: Uri.parse(nativeLink),
          ),
          android: AndroidConfiguration(domain: Uri.parse(universal)),
        );
        await CoinbaseWalletSDK.shared.configure(config);
      } catch (_) {
        // Silent error
      }
    } else {
      throw W3MCoinbaseException('Initialization error');
    }
  }

  @protected
  @override
  Future<void> cbGetAccount() async {
    await _checkInstalled();
    try {
      final results = await CoinbaseWalletSDK.shared.initiateHandshake([
        const RequestAccounts(),
      ]);
      final result = results.first;
      if (result.error != null) {
        final errorCode = result.error?.code;
        final errorMessage = result.error!.message;
        onCoinbaseError.broadcast(CoinbaseErrorEvent(errorMessage));
        throw W3MCoinbaseException('$errorMessage ($errorCode)');
      }

      final data = CoinbaseData.fromJson(result.account!.toJson());
      onCoinbaseConnect.broadcast(CoinbaseConnectEvent(data));
      return;
    } on PlatformException catch (e, s) {
      // Currently Coinbase SDK is not differentiate between User rejection or any other kind of error in iOS
      final errorMessage = (e.message ?? '').toLowerCase();
      onCoinbaseError.broadcast(CoinbaseErrorEvent(errorMessage));
      throw W3MCoinbaseException(errorMessage, e, s);
    } catch (e, s) {
      onCoinbaseError.broadcast(CoinbaseErrorEvent('Initial handshake error'));
      throw W3MCoinbaseException('Initial handshake error', e, s);
    }
  }

  @override
  Future<dynamic> cbRequest({
    String? chainId,
    required SessionRequestParams request,
  }) async {
    await _checkInstalled();
    try {
      final req = Request(actions: [request.toCoinbaseRequest(chainId)]);
      final result = (await CoinbaseWalletSDK.shared.makeRequest(req)).first;
      if (result.error != null) {
        final errorCode = result.error?.code;
        final errorMessage = result.error!.message;
        onCoinbaseError.broadcast(CoinbaseErrorEvent(errorMessage));
        throw W3MCoinbaseException('$errorMessage ($errorCode)');
      }
      switch (req.actions.first.method) {
        case 'wallet_switchEthereumChain':
        case 'wallet_addEthereumChain':
          final event = CoinbaseSessionEvent(chainId: chainId);
          onCoinbaseSessionUpdate.broadcast(event);
          break;
        case 'eth_requestAccounts':
          final json = jsonDecode(result.value!);
          final data = CoinbaseData.fromJson(json);
          onCoinbaseConnect.broadcast(CoinbaseConnectEvent(data));
          break;
        default:
          final data = result.value;
          onCoinbaseResponse.broadcast(CoinbaseResponseEvent(data: data));
          break;
      }
      return result.value;
    } catch (e, s) {
      if (e is W3MCoinbaseException) {
        rethrow;
      }
      onCoinbaseError.broadcast(CoinbaseErrorEvent('Request error'));
      throw W3MCoinbaseException('Request error', e, s);
    }
  }

  @override
  Future<bool> cbIsInstalled() async {
    try {
      return await CoinbaseWalletSDK.shared.isAppInstalled();
    } catch (e, s) {
      throw W3MCoinbaseException('Check is installed error', e, s);
    }
  }

  @override
  Future<bool> cbIsConnected() async {
    try {
      return await CoinbaseWalletSDK.shared.isConnected();
    } catch (e, s) {
      throw W3MCoinbaseException('Check is connected error', e, s);
    }
  }

  @override
  Future<void> cbResetSession() async {
    try {
      return CoinbaseWalletSDK.shared.resetSession();
    } catch (e, s) {
      throw W3MCoinbaseException('Reset session error', e, s);
    }
  }

  Future<bool> _checkInstalled() async {
    final installed = await cbIsInstalled();
    if (!installed) {
      throw W3MCoinbaseNotInstalledException();
    }
    return true;
  }
}

extension on SessionRequestParams {
  Action toCoinbaseRequest(String? chainId) {
    switch (method) {
      case 'personal_sign':
        final address = _getAddressFromParamsList(params);
        final message = _getDataFromParamsList(params);
        return PersonalSign(address: address, message: message);
      case 'eth_signTypedData_v3':
        final address = _getAddressFromParamsList(params);
        final jsonData = _getDataFromParamsList(params);
        return SignTypedDataV3(address: address, typedDataJson: jsonData);
      case 'eth_signTypedData_v4':
        final address = _getAddressFromParamsList(params);
        final jsonData = _getDataFromParamsList(params);
        return SignTypedDataV4(address: address, typedDataJson: jsonData);
      case 'eth_requestAccounts':
        return RequestAccounts();
      case 'eth_signTransaction':
        final jsonData = _getTransactionFromParams(params);
        final hexValue = jsonData['value'].toString().replaceFirst('0x', '');
        final value = int.parse(hexValue, radix: 16);
        return SignTransaction(
          fromAddress: jsonData['from'],
          toAddress: jsonData['to'],
          chainId: chainId!,
          weiValue: BigInt.from(value),
          data: jsonData['data'],
        );
      case 'eth_sendTransaction':
        final jsonData = _getTransactionFromParams(params);
        return SendTransaction(
          fromAddress: jsonData['from'],
          toAddress: jsonData['to'],
          chainId: chainId!,
          weiValue: jsonData['value'],
          data: jsonData['data'],
        );
      case 'wallet_switchEthereumChain':
      case 'wallet_addEthereumChain':
        try {
          final chainInfo = W3MChainPresets.chains[chainId!]!;
          final iconUrls =
              chainInfo.chainIcon != null ? [chainInfo.chainIcon!] : null;
          final explorerUrls = chainInfo.blockExplorer != null
              ? [chainInfo.blockExplorer!.url]
              : null;
          return AddEthereumChain(
            chainId: chainInfo.chainId,
            rpcUrls: [chainInfo.rpcUrl],
            chainName: chainInfo.chainName,
            nativeCurrency: Currency(
              name: chainInfo.tokenName,
              symbol: chainInfo.tokenName,
              decimals: 18,
            ),
            iconUrls: iconUrls,
            blockExplorerUrls: explorerUrls,
          );
        } catch (e, s) {
          throw W3MCoinbaseException('Unrecognized chainId $chainId', e, s);
        }
      case 'wallet_watchAsset':
        return WatchAsset(params: params);
      default:
        throw W3MCoinbaseException('Unsupported request method $method');
    }
  }

  String _getAddressFromParamsList(dynamic params) {
    return (params as List).firstWhere((p) {
      try {
        EthereumAddress.fromHex(p);
        return true;
      } catch (e) {
        return false;
      }
    });
  }

  dynamic _getDataFromParamsList(dynamic params) {
    return (params as List).firstWhere((p) {
      final address = _getAddressFromParamsList(params);
      return p != address;
    });
  }

  Map<String, dynamic> _getTransactionFromParams(dynamic params) {
    final param = (params as List<dynamic>).first;
    return param as Map<String, dynamic>;
  }
}

class WatchAsset extends Action {
  WatchAsset({required dynamic params})
      : super(
          method: 'wallet_watchAsset',
          paramsJson: jsonEncode(params),
        );
}
