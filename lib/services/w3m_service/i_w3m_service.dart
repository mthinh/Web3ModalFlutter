import 'package:flutter/material.dart';

import 'package:web3modal_flutter/web3modal_flutter.dart';
import 'package:web3modal_flutter/services/w3m_service/models/w3m_session.dart';

enum W3MServiceStatus {
  idle,
  initializing,
  initialized,
  error;

  bool get isInitialized => this == initialized;
  bool get isLoading => this == initializing;
}

class W3MServiceException implements Exception {
  final dynamic message;
  final dynamic stackTrace;
  W3MServiceException(this.message, [this.stackTrace]) : super();
}

class WalletErrorEvent implements EventArgs {
  final String message;
  WalletErrorEvent(this.message);
}

class WalletNotInstalled extends WalletErrorEvent {
  WalletNotInstalled() : super('Wallet app not installed');
}

class ErrorOpeningWallet extends WalletErrorEvent {
  ErrorOpeningWallet() : super('Unable to open Wallet app');
}

class UserRejectedConnection extends WalletErrorEvent {
  UserRejectedConnection() : super('User rejected Wallet connection');
}

/// Either a [projectId] and [metadata] must be provided or an already created [web3App].
/// optionalNamespaces is mostly not needed, if you use it, the values set here will override every optionalNamespaces set in evey chain
abstract class IW3MService with ChangeNotifier {
  /// Whether or not this object has been initialized.
  W3MServiceStatus get status;

  bool get hasNamespaces;

  /// The object that manages sessions, authentication, events, and requests for WalletConnect.
  IWeb3App? get web3App;

  /// Variable that can be used to check if the modal is visible on screen.
  bool get isOpen;

  /// Variable that can be used to check if the web3App is connected
  bool get isConnected;

  /// The URI that can be used to connect to this dApp.
  /// This is only available after the [openModal] function is called.
  String? get wcUri;

  /// The current session's data.
  W3MSession? get session;

  /// The url to the account's avatar image.
  /// Pass this into a [Image.network] and it will load the avatar image.
  String? get avatarUrl;

  /// Returns the balance of the currently connected wallet on the selected chain.
  double? get chainBalance;

  /// The currently selected chain.
  W3MChainInfo? get selectedChain;

  /// The currently selected wallet.
  W3MWalletInfo? get selectedWallet;

  /// Sets up the explorer and the web3App if they already been initialized.
  Future<void> init();

  /// Opens the modal with the provided [startWidget] (if any).
  /// If none is provided, the default state will be used based on platform.
  Future<void> openModal(BuildContext context, [Widget? startWidget]);

  /// Connects to the relay if not already connected.
  /// If the relay is already connected, this does nothing.
  Future<void> reconnectRelay();

  /// Sets the [selectedWallet] to be connected
  void selectWallet(W3MWalletInfo walletInfo);

  /// Sets the [selectedChain] and gets the [chainBalance].
  /// If the wallet is already connected, it will request the chain to be changed and will update the session with the new chain.
  /// If [chainInfo] is null this will disconnect the wallet.
  Future<void> selectChain(W3MChainInfo? chainInfo, {bool switchChain = false});

  /// Launch blockchain explorer for the current chain in external browser
  void launchBlockExplorer();

  /// Used to expire and delete any inactive pairing
  Future<void> expirePreviousInactivePairings();

  /// This will do nothing if [isConnected] is true.
  Future<void> buildConnectionUri();

  /// Connects the [selectedWallet] previously selected
  Future<void> connectSelectedWallet({bool inBrowser = false});

  /// Opens the native wallet [selectedWallet] after connected
  Future<void> launchConnectedWallet();

  /// List of available chains to be added in connected wallet
  List<String>? getAvailableChains();

  /// List of approved chains by connected wallet
  List<String>? getApprovedChains();

  /// List of approved methods by connected wallet
  List<String>? getApprovedMethods();

  /// List of approved events by connected wallet
  List<String>? getApprovedEvents();

  /// Disconnects the session and pairing, if any.
  /// If there is no session, this does nothing.
  Future<void> disconnect({bool disconnectAllSessions = true});

  Future<dynamic> requestReadContract({
    required DeployedContract deployedContract,
    required String functionName,
    required String rpcUrl,
    List parameters = const [],
  });

  Future<dynamic> requestWriteContract({
    required String topic,
    required String chainId,
    required String rpcUrl,
    required DeployedContract deployedContract,
    required String functionName,
    required Transaction transaction,
    String? method,
    List parameters = const [],
  });

  /// Make a request
  Future<dynamic> request({
    required String topic,
    required String chainId,
    String? switchToChainId,
    required SessionRequestParams request,
  });

  /// Closes the modal.
  void closeModal();

  @override
  void dispose();

  /* EVENTS DECLARATIONS */

  abstract final Event<SessionConnect> onSessionConnectEvent;
  abstract final Event<SessionDelete> onSessionDeleteEvent;
  abstract final Event<SessionExpire> onSessionExpireEvent;
  abstract final Event<SessionUpdate> onSessionUpdateEvent;
  abstract final Event<SessionEvent> onSessionEventEvent;
  abstract final Event<PairingEvent> onPairingExpire;
  abstract final Event<WalletErrorEvent> onWalletConnectionError;
}
