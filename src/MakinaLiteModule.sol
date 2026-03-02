// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import {IMakinaLiteModule} from "./interfaces/IMakinaLiteModule.sol";
import {MakinaLiteGovernable} from "./utils/MakinaLiteGovernable.sol";

contract MakinaLiteModule is MakinaLiteGovernable, IMakinaLiteModule {
    constructor(address _safe, address _provider) MakinaLiteGovernable(_safe, _provider) {}
}
